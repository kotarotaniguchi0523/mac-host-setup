{
  home,
  user,
  repoDir,
  ...
}:
let
  log = "${home}/Library/Logs/mac-host-setup-check.log";
  # PATH for everything launchd starts in this login session (GUI apps such as AI desktop apps,
  # and the shells and tools they spawn without reading zsh's startup files). Same order as zsh:
  # Nix profiles, then the global mise tools (shims: no `mise activate` outside interactive zsh),
  # system, then the dirs outside the declarations (appended, so declared tools win).
  # zsh resets PATH itself (/etc/zshenv, nix-darwin), so this does not change shells.
  sessionPath = builtins.concatStringsSep ":" [
    "${home}/.nix-profile/bin"
    "/etc/profiles/per-user/${user}/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
    "${home}/.local/share/mise/shims"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
    "${home}/.docker/bin"
    "${home}/.local/bin"
  ];
in
{
  # Sets that PATH at every login (`launchctl setenv` alone does not survive a reboot).
  # Apps started after it inherit it; an app already running keeps its old PATH until restarted.
  launchd.agents.session-path = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/launchctl"
        "setenv"
        "PATH"
        sessionPath
      ];
      RunAtLoad = true;
    };
  };

  # Read-only daily check (replaces the Windows Task Scheduler job).
  # It never applies anything and never uses sudo: it fetches origin, compares the host
  # with the declarations, writes .agent/update-report.json and posts a notification.
  # Applying stays manual: tools/update.sh (origin/main only).
  launchd.agents.mac-host-setup-check = {
    enable = true;
    config = {
      ProgramArguments = [
        "/bin/zsh"
        "-lc"
        "${repoDir}/tools/check.sh --notify"
      ];
      StartCalendarInterval = [
        {
          Hour = 8;
          Minute = 30;
        }
      ];
      StandardOutPath = log;
      StandardErrorPath = log;
    };
  };
}
