{
  description = "mac-host-setup: macOS host declarations (nix-darwin + home-manager + mise)";

  # All inputs are pinned exactly by flake.lock (rev + narHash). Do not run
  # `nix flake update` on the host: flake.lock changes arrive only via PR.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager, ... }:
    let
      system = "aarch64-darwin";
      # The user name and repository path are read from the environment so that no
      # personal value is committed. Build with --impure (tools/update.sh does this).
      user = builtins.getEnv "USER";
      home = builtins.getEnv "HOME";
      repoDir = "${home}/src/mac-host-setup";
    in
    {
      darwinConfigurations.default = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit self user home repoDir; };
        modules = [
          ./hosts/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit user home repoDir; };
            home-manager.users.${user} = import ./home;
          }
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
