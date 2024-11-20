{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    kclpkgs.url = "github:appthrust/kcl-nix/f5c3590ab4ed12c307219a1dda489a49b52655ca";
  };

  outputs = { self, nixpkgs, nixpkgs-2405, flake-utils, kclpkgs }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        pkgs-2405 = import nixpkgs-2405 {
          inherit system;
        };
        kcl = kclpkgs.default.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            awscli2
            bun
            fish
            flarectl
            gnugrep
            gnused
            gum
            helmfile
            just
            crossplane-cli
            k3d
            kind
            kubectl
            kubectl-view-secret
            kubernetes-helm
            kubeseal
            terraform
            yamllint
            yq-go
            zsh
            kcl.cli
            kcl.language-server
            kcl.kubectl-kcl
          ] ++ (with pkgs-2405; [ ]);
          shellHook = ''
            						export KUBECONFIG="$(pwd)/kubeconfig.yaml"
          '';
        };
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
