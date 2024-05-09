{
  inputs = {
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    systems,
    nixpkgs,
    ...
  } @ inputs: let
    eachSystem = f:
      nixpkgs.lib.genAttrs (import systems) (
        system:
          f nixpkgs.legacyPackages.${system}
      );
  in {

    devShells = eachSystem (pkgs: {
      default = pkgs.mkShell {
        # TODO get github:akatch/metar as well
        shellHook = ''
          echo -n "whee weather"
        '';
        buildInputs = with pkgs; [
          erlang
          elixir
        ];
      };
    });
  };
}
