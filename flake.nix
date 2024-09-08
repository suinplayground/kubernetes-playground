{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    kclpkgs.url = "github:appthrust/kcl-nix";
  };

  outputs = { self, nixpkgs, nixpkgs-2405, flake-utils, kclpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        pkgs-2405 = import nixpkgs-2405 {
          inherit system;
        };
        kcl = kclpkgs.default.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            fish
            gnugrep
            gnused
            gum
            helmfile
            just
            crossplane-cli
            k3d
            kubectl
            kubectl-view-secret
            kubernetes-helm
            kubeseal
            yamllint
            yq-go
            zsh
            kcl.cli
            kcl.language-server
          ] ++ (with pkgs-2405; [ ]);
          shellHook = ''
            						export KUBECONFIG="$(pwd)/kubeconfig.yaml"
                        exec fish
          '';
        };
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
