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
    gopls
    rust-analyzer
    # --- CLI
    jq
    jujutsu
    nushell
    betterleaks
    rtk
    ghq
    # --- Docker Sandboxes (sbx-setup builds and loads its templates from the host; the sandbox
    #     tools themselves live in the templates). Docker Desktop is an exception (exceptions.tsv).
    # The install check (`sbx version` run inside the build) makes macOS lock Sbx.app, and the store
    # write then fails ("clearing flags of path ...: Operation not permitted"). Skipped here;
    # tools/check.sh verifies the bundle's Docker signature instead.
    (docker-sbx.overrideAttrs { doInstallCheck = false; })
    lefthook
    # --- AI agents
    pi-coding-agent
    agent-browser
  ];

  programs.zsh = {
    enable = true;
    # Docker Desktop (exception: exceptions.tsv / AUDIT.md) used to append this to ~/.zprofile,
    # which home-manager now owns. Same position as before: appended.
    # ~/.local/bin holds installs made outside these declarations (Claude Code's own installer).
    # Appended (after the Nix profiles) so a declared tool always wins over a stray one;
    # tools/check.sh still reports what is in there (AUDIT.md "既知の野良").
    # In .zshenv (every zsh: login, interactive, `zsh -c` from tools and agents), not .zprofile
    # (login shells only). Appended after the PATH /etc/zshenv (nix-darwin) sets; `typeset -U`
    # keeps it from repeating when a nested shell reads it again.
    # mise shims for non-interactive shells only (mise's recommendation): `mise activate` (.zshrc)
    # runs only in interactive shells, so without them the global mise tools (pnpm, textlint, ...)
    # are missing from scripts and agents' `zsh -c`. Interactive shells must not get them:
    # `mise activate` moves the shims ahead of the Nix profiles, and a shim of a repo-only tool
    # (e.g. betterleaks) then fails outside that repo with "No version is set".
    envExtra = ''
      typeset -U path
      [[ -o interactive ]] || path+=("$HOME/.local/share/mise/shims")
      path+=("$HOME/.docker/bin" "$HOME/.local/bin")
    '';
  };

  # Puts the global mise tools (mise/mise.toml) on PATH in zsh, ahead of ~/.local/bin.
  # The config file itself is copied by tools/update.sh (not managed here: mise writes its lock).
  programs.mise = {
    enable = true;
    # Official release binary pinned in pkgs/mise-bin.json (attestation + GPG verified by
    # tools/ci/mise-bin-update.sh); nixpkgs' build lagged ~3 weeks behind upstream.
    package = pkgs.callPackage ../pkgs/mise-bin.nix { };
    enableZshIntegration = true;
  };
}
