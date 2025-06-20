# Cluster API管理クラスタとワークロードクラスタでmirror.gcr.ioをDocker Hubミラーとして利用する方法

## はじめに

Kubernetesクラスタを運用する際、特にCI/CDパイプラインやプロトタイピング中に、Docker Hubのレートリミットに遭遇することがあります。この制限は、イメージのプル失敗や不要な遅延を引き起こし、ワークフローに大きな支障をきたします。これを回避するために、[mirror.gcr.io](https://cloud.google.com/container-registry/docs/pulling-cached-images) をDocker Hubイメージのプルスルーキャッシュとして利用することができます。本ガイドでは、[Cluster API](https://cluster-api.sigs.k8s.io/) を用いた**管理クラスタ**と**ワークロードクラスタ**の両方でmirror.gcr.ioをレジストリミラーとして設定し、Docker Hubのレートリミットを回避する方法を解説します。

---

## なぜmirror.gcr.ioを使うのか？

- **Docker Hubのレートリミット回避**: mirror.gcr.ioはDocker Hubイメージをキャッシュし、クラスタは直接Docker HubではなくGoogleのミラーからイメージを取得します。
- **イメージプルの高速化**: キャッシュされたイメージはGoogleのインフラから高速に配信されます。
- **信頼性向上**: Docker Hubの障害やスロットリングによる影響を回避できます。

---

## 前提条件

- [Docker](https://docs.docker.com/get-docker/) のインストール
- [kind](https://kind.sigs.k8s.io/)（Kubernetes IN Docker）のインストール
- [kubectl](https://kubernetes.io/docs/tasks/tools/) のインストール
- [clusterctl](https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl) のインストール
- [yq](https://github.com/mikefarah/yq) のインストール（YAML処理用）

---

## ステップ1: レジストリミラー設定ファイルの準備

containerdがDocker Hubのミラーとしてmirror.gcr.ioを利用できるよう、ディレクトリ構造と設定ファイルを作成します。

```bash
mkdir -p certs.d/docker.io
cat > certs.d/docker.io/hosts.toml <<EOF
server = "https://registry-1.docker.io"

[host."https://mirror.gcr.io"]
  capabilities = ["pull"]

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
EOF
```

この設定は、プルと解決の操作を分離し、古いキャッシュの問題を防ぎます。mirror.gcr.ioはイメージプル（キャッシュされたイメージを活用）を処理し、registry-1.docker.ioはタグ解決とメタデータクエリを処理することで、キャッシュの古さを防ぎながら常に最新のタグ情報を取得できます。

---

## ステップ2: kindクラスタのミラー設定

以下の内容で `kind-cluster.yaml` ファイルを作成します。これにより、kind内部のcontainerdがミラーを利用し、デバッグログも有効化されます。

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  ipFamily: dual
nodes:
  - role: control-plane
    image: kindest/node:v1.33.1
    extraMounts:
      # Cluster API Docker Provider（CAPD）がホストのDockerを操作できるようにDockerソケットをマウント
      - hostPath: /var/run/docker.sock
        containerPath: /var/run/docker.sock
      # ミラー設定をcontainerdの設定ディレクトリにマウント
      - hostPath: ./certs.d
        containerPath: /etc/containerd/certs.d
# containerdにdocker.ioとregistry.k8s.ioのイメージ取得時にmirror.gcr.ioを優先させる
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry]
      config_path = "/etc/containerd/certs.d"
    # mirror.gcr.ioの利用状況を確認するためデバッグモードを有効化
    # ログ確認例: `docker exec -it <cluster名>-control-plane bash -c 'journalctl -u containerd -f & crictl pull nginx'`
    [debug]
      level = "debug"
```

**各項目の詳細解説：**

- `kind: Cluster` と `apiVersion`: kindクラスタ設定であることを示します。
- `networking.ipFamily: dual`: IPv4とIPv6の両方を有効化。
- `nodes`: クラスタ内のノード定義。ここではコントロールプレーン1台。
- `image`: ノードイメージのバージョン（Kubernetesバージョンに合わせて選択）。
- `extraMounts`:
  - CAPDがDockerを操作するためのソケットマウント。
  - ミラー設定（certs.d）をノード内のcontainerd設定ディレクトリにマウント。
- `containerdConfigPatches`:
  - containerdにカスタムレジストリ設定パスを指定。
  - デバッグログを有効化し、イメージプルやミラー利用のトラブルシュートを容易に。

---

## ステップ3: 管理クラスタの作成

```bash
kind create cluster --name management --config kind-cluster.yaml
```

このコマンドで、カスタムレジストリ設定とデバッグログが有効な管理クラスタが作成されます。ミラーが利用されているかは、以下のコマンドで確認できます：

```bash
docker exec -it management-control-plane bash -c 'crictl pull hello-world && journalctl -u containerd' | grep fetch | grep mirror.gcr.io
```

`mirror.gcr.io`からイメージが取得されているログが表示されれば成功です。

---

## ステップ4: 管理クラスタへのCluster APIインストール

```bash
clusterctl init --infrastructure docker
```

これで管理クラスタにCluster APIコンポーネントがインストールされます。

---

## ステップ5: ワークロードクラスタテンプレートへのミラーパッチ適用

Cluster APIでワークロードクラスタを作成する際、ノードにもミラー設定が反映されるよう、クラスタテンプレートに事前コマンドを注入します。

以下の内容で `patch.yaml` を作成します：

```yaml
- name: containerd-customization
  description: "containerdのミラー・デバッグ・再起動設定"
  definitions:
    - selector:
        apiVersion: controlplane.cluster.x-k8s.io/v1beta1
        kind: KubeadmControlPlaneTemplate
        matchResources:
          controlPlane: true
      jsonPatches:
        - op: add
          path: /spec/template/spec/kubeadmConfigSpec/preKubeadmCommands
          value:
            - |
              # すべてを制すワンライナー
              set -e

              # 1. ミラー用hosts.toml作成
              mkdir -p /etc/containerd/certs.d/docker.io
              cat <<EOF > /etc/containerd/certs.d/docker.io/hosts.toml
              server = "https://registry-1.docker.io"

              [host."https://mirror.gcr.io"]
                capabilities = ["pull"]

              [host."https://registry-1.docker.io"]
                capabilities = ["pull", "resolve"]
              EOF

              # 2. デバッグ設定を冪等に追加
              if ! grep -q '\[debug\]' /etc/containerd/config.toml; then
                sed -i '/version = 2/a [debug]\n  level = "debug"' /etc/containerd/config.toml
              fi

              # 3. registry config_pathを冪等に追加
              if ! grep -q 'config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml; then
                printf '\n[plugins."io.containerd.grpc.v1.cri".registry]\n  config_path = "/etc/containerd/certs.d"\n' >> /etc/containerd/config.toml
              fi

              # 4. containerdを再起動して反映
              systemctl restart containerd
    - selector:
        apiVersion: bootstrap.cluster.x-k8s.io/v1beta1
        kind: KubeadmConfigTemplate
        matchResources:
          machineDeploymentClass:
            names: ["default-worker"]
      jsonPatches:
        - op: add
          path: /spec/template/spec/preKubeadmCommands
          value:
            - |
              # すべてを制すワンライナー
              set -e

              # 1. ミラー用hosts.toml作成
              mkdir -p /etc/containerd/certs.d/docker.io
              cat <<EOF > /etc/containerd/certs.d/docker.io/hosts.toml
              server = "https://registry-1.docker.io"

              [host."https://mirror.gcr.io"]
                capabilities = ["pull"]

              [host."https://registry-1.docker.io"]
                capabilities = ["pull", "resolve"]
              EOF

              # 2. デバッグ設定を冪等に追加
              if ! grep -q '\[debug\]' /etc/containerd/config.toml; then
                sed -i '/version = 2/a [debug]\n  level = "debug"' /etc/containerd/config.toml
              fi

              # 3. registry config_pathを冪等に追加
              if ! grep -q 'config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml; then
                printf '\n[plugins."io.containerd.grpc.v1.cri".registry]\n  config_path = "/etc/containerd/certs.d"\n' >> /etc/containerd/config.toml
              fi

              # 4. containerdを再起動して反映
              systemctl restart containerd
```

**各項目の詳細解説：**

- `name`と`description`: パッチの目的を示すメタデータ。
- `definitions`: ノード種別ごとのパッチ定義リスト。
- 各`selector`は特定のCluster APIテンプレート種別（コントロールプレーンまたはワーカーノード）をターゲット。
- `jsonPatches`: ノードの起動プロセスにコマンドを注入するJSONパッチ操作。
- `preKubeadmCommands`内のシェルスクリプトは：
  1. **ミラー設定作成**: containerd用のhosts.tomlを作成。
  2. **デバッグログ有効化**: containerd設定にdebugセクションを追加（未設定時のみ）。
  3. **registry config_path設定**: containerdにミラー設定パスを認識させる。
  4. **containerd再起動**: 設定反映のためサービス再起動。
- このパッチはコントロールプレーン・ワーカーノード両方に適用され、全ノードでミラーが利用されます。

---

## ステップ6: ワークロードクラスタマニフェストの生成と適用

このステップでは、ワークロードクラスタのマニフェストを生成し、containerdカスタマイズパッチを適用してから管理クラスタに適用します。各コマンドの意味と流れは以下の通りです：

- **クラスタマニフェスト生成**: `clusterctl generate cluster workload ...` で新しいワークロードクラスタのYAMLマニフェストを生成します（トポロジー、マシンテンプレート、設定など）。
- **yqでYAML整形**: 最初の`yq`でYAMLをパースし、後続処理しやすくします。
- **オリジナル保存**: `tee workload.original.yaml`で未パッチのマニフェストを保存。
- **ClusterClassへパッチ適用**: 2つ目の`yq`で`ClusterClass`の`spec.patches`に`patch.yaml`の内容を追加。これによりクラスタ作成時にpreKubeadmCommands（ミラー設定）がノード起動時に注入されます。
- **パッチ済みマニフェスト保存**: `tee workload.patched.yaml`でパッチ済みマニフェストを保存。
- **クラスタへ適用**: `kubectl apply -f -`でパッチ済みマニフェストを管理クラスタに適用し、ワークロードクラスタが作成されます。

```bash
clusterctl generate cluster workload \
  --flavor development \
  --kubernetes-version v1.33.1 \
  --control-plane-machine-count=1 \
  --worker-machine-count=1 \
  | yq \
  | tee workload.original.yaml \
  | yq 'select(.kind == "ClusterClass").spec.patches += load("patch.yaml")' \
  | tee workload.patched.yaml \
  | kubectl apply -f -
```

**この時何が起こるか：**

- 管理クラスタがマニフェストを受け取り、ワークロードクラスタの作成を開始します。
- 各ノードは起動時にパッチで注入されたpreKubeadmCommandsを実行し、containerdがmirror.gcr.ioを利用するよう設定されます。
- 以降、これらノードでのイメージプルはDocker Hubのレートリミットを回避し、mirror.gcr.io経由となります。
- オリジナル・パッチ済み両方のマニフェストを確認することで、実際に何がデプロイされるかを把握できます。

---

## ステップ7: ワークロードクラスタでミラー利用を確認

ワークロードクラスタのノードがミラーを利用しているか確認するには、以下を実行します：

```bash
for container in $(kubectl --context=kind-management get machines -o custom-columns=NAME:.metadata.name --no-headers); do
  echo
  echo === $container ===
  docker exec -it $container bash -c 'crictl pull hello-world && journalctl -u containerd' | grep fetch | grep mirror.gcr.io
done
```

各ノードで`mirror.gcr.io`からイメージが取得されているログが表示されれば成功です。

---

## ステップ8: (オプション) CNIプラグインのインストール

例：Calicoをインストールする場合

```bash
kubectl --context=kind-workload apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
```

---

## まとめ

これらの手順により、管理クラスタ・ワークロードクラスタの両方でmirror.gcr.ioをDocker Hubイメージのプルスルーキャッシュとして利用できます。これによりDocker Hubのレートリミットを回避し、Kubernetesワークロードのイメージプルが高速かつ安定します。

---

## 参考リンク

- [Google Container Registry Mirror](https://cloud.google.com/container-registry/docs/pulling-cached-images)
- [kind Registry Configuration](https://kind.sigs.k8s.io/docs/user/local-registry/)
- [Cluster API Book](https://cluster-api.sigs.k8s.io/)
