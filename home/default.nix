{
  pkgs,
  user,
  home,
  ...
}:
{
  imports = [ ./launchd.nix ];

  home.username = user;
  home.homeDirectory = home;
  home.stateVersion = "26.05";

  # Global CLIs from Nix (nixpkgs pinned by flake.lock). Every entry has a decision in AUDIT.md
  # (tools/compare-source.sh). Tools that win on the mise side are in mise/mise.toml.
  home.packages = with pkgs; [
    # --- base (mise itself comes from programs.mise below)
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
    # --- GUI apps (AGENTS.md: App Store -> nixpkgs -> vendor dmg)
    t3code # T3 Code desktop + `t3` CLI, built from source
    ctx7
  ];

  # ~/.local/bin holds installs made outside these declarations (Claude Code's own installer,
  # the T3 Code desktop app's `t3` shim). Kept on PATH until they are
  # moved into the declarations (AUDIT.md "既知の野良"). tools/check.sh still reports them.
  home.sessionPath = [ "$HOME/.local/bin" ];

  programs.zsh = {
    enable = true;
    # Docker Desktop (installed outside these declarations) used to append this to ~/.zprofile,
    # which home-manager now owns. Same position as before: appended.
    profileExtra = ''
      export PATH="$PATH:$HOME/.docker/bin"
    '';
  };

  # Puts the global mise tools (mise/mise.toml) on PATH in zsh, ahead of ~/.local/bin.
  # The config file itself is copied by tools/update.sh (not managed here: mise writes its lock).
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
  };
}
