{
  home,
  repoDir,
  ...
}:
let
  log = "${home}/Library/Logs/mac-host-setup-check.log";
in
{
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
