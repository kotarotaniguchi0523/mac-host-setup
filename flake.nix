{
  description = "mac-host-setup: macOS host declarations (nix-darwin + home-manager + mise)";

  # All inputs are pinned exactly by flake.lock (rev + narHash). Do not run
  # `nix flake update` on the host: flake.lock changes arrive only via PR.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      ...
    }:
    let
      system = "aarch64-darwin";
      # The user name and repository path are read from the environment so that no
      # personal value is committed. Build with --impure (tools/update.sh does this).
      user = builtins.getEnv "USER";
      home = builtins.getEnv "HOME";
      # Fail loudly instead of building for user "" (e.g. evaluated without --impure, or under sudo -i).
      checked =
        assert user != "" && user != "root" && home != "";
        assert builtins.pathExists "${repoDir}/flake.nix";
        true;
      # Where this checkout lives (repositories are managed by ghq, so the path is not fixed).
      # tools/lib.sh exports it; plain `nix` commands run from the repository root fall back to PWD.
      # The launchd check agent runs tools/check.sh from here, so after moving the checkout,
      # run tools/update.sh from the new place once.
      repoDir =
        let
          dir = builtins.getEnv "MAC_HOST_SETUP_DIR";
        in
        if dir != "" then dir else builtins.getEnv "PWD";
    in
    {
      darwinConfigurations.default =
        assert checked;
        nix-darwin.lib.darwinSystem {
          specialArgs = {
            inherit
              system
              self
              user
              home
              repoDir
              ;
          };
          modules = [
            ./hosts/darwin.nix
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Existing dotfiles (e.g. ~/.zshrc) are kept as *.before-home-manager instead of failing.
              home-manager.backupFileExtension = "before-home-manager";
              home-manager.extraSpecialArgs = { inherit user home repoDir; };
              home-manager.users.${user} = import ./home;
            }
          ];
        };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;

      # APM (Skills) for tools/skills-apply.sh and CI: the same build as the one on the host PATH.
      packages.${system}.apm = nixpkgs.legacyPackages.${system}.apm-cli;
    };
}
