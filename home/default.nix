{ pkgs, user, home, ... }:
{
  imports = [ ./launchd.nix ];

  home.username = user;
  home.homeDirectory = home;
  home.stateVersion = "26.05";

  # Global CLIs that come from Nix. Each entry must have a decision in AUDIT.md
  # (tools/compare-source.sh). Tools that win on the mise side go to mise/mise.toml.
  home.packages = with pkgs; [
    mise # bootstrap for the mise lane (comparison pending in AUDIT.md)
  ];

  programs.zsh.enable = true;
}
