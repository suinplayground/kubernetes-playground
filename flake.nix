{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, nixpkgs-2405, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
				pkgs-2405 = import nixpkgs-2405 {
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
            yq-go
          ] ++ (with pkgs-2405; []);
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
