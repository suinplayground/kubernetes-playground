{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
          	helmfile
          	just
            crossplane-cli
            k3d
            kind
            kubectl
            kubernetes-helm
            tilt
            yamllint
          ];
          shellHook = ''
            if [ -n "$SHELL" ]; then
              exec $SHELL
            else
              echo "SHELL environment variable is not set. Using default shell."
            fi
          '';
        };
        formatter = pkgs.nixpkgs-fmt;
      }
    );
}
