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
    # pip included, so `pip` / `pip3` are this Python's (not macOS's /usr/bin/pip3 = Python 3.9).
    # Installs outside a venv are still refused: PIP_REQUIRE_VIRTUALENV (mise/mise.toml [env]).
    (python315.withPackages (ps: [ ps.pip ]))
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
    textlint
    rtk
    # --- AI agents
    pi-coding-agent
    agent-browser
    ctx7
  ];

  programs.zsh = {
    enable = true;
    # Docker Desktop (installed outside these declarations) used to append this to ~/.zprofile,
    # which home-manager now owns. Same position as before: appended.
    # ~/.local/bin holds installs made outside these declarations (Claude Code's own installer).
    # Appended (after the Nix profiles) so a declared tool always wins over a stray one;
    # tools/check.sh still reports what is in there (AUDIT.md "既知の野良").
    profileExtra = ''
      export PATH="$PATH:$HOME/.docker/bin:$HOME/.local/bin"
    '';
  };

  # Puts the global mise tools (mise/mise.toml) on PATH in zsh, ahead of ~/.local/bin.
  # The config file itself is copied by tools/update.sh (not managed here: mise writes its lock).
  programs.mise = {
    enable = true;
    enableZshIntegration = true;
  };
}
