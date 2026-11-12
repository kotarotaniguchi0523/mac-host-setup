{
  system,
  self,
  user,
  home,
  lib,
  ...
}:
{
  # --- Nix itself (upstream Nix installed by tools/install-nix.sh) --------------------
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = [ "https://cache.nixos.org" ];
    trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
    require-sigs = true;
    accept-flake-config = false;
    sandbox = true;
    # Only root may add substituters / keys; normal users cannot widen trust.
    trusted-users = [ "root" ];
  };

  # Unfree packages are allowed by name only (AGENTS.md).
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "docker-sbx" # Docker Sandboxes CLI (AUDIT.md)
    ];

  # --- System --------------------------------------------------------------------------
  system.primaryUser = user;
  users.users.${user}.home = home;

  # Homebrew is not used (AGENTS.md). nix-darwin's homebrew module stays disabled.
  homebrew.enable = false;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;
  nixpkgs.hostPlatform = system;
}
