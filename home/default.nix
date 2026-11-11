{ pkgs, user, home, ... }:
{
  imports = [ ./launchd.nix ];

  home.username = user;
  home.homeDirectory = home;
  home.stateVersion = "26.05";

  # Global CLIs from Nix (nixpkgs pinned by flake.lock). Every entry has a decision in AUDIT.md
  # (tools/compare-source.sh). Tools that win on the mise side are in mise/mise.toml.
  home.packages = with pkgs; [
    # --- base / package managers
    mise
    gh
    # --- runtimes (only the default line is global; older lines are per project via mise)
    nodejs_26
    python315
    go_1_27
    rustc
    cargo
    clippy
    rustfmt
    # --- language tooling
    uv
    pnpm
    gopls
    rust-analyzer
    # --- CLI
    jq
    jujutsu
    nushell
    betterleaks
    doppler
    dotenvx
    textlint
    rtk
    # --- AI agents
    codex
    opencode
    pi-coding-agent
    agent-browser
    ctx7
  ];

  programs.zsh.enable = true;
}
