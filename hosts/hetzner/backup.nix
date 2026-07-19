# Nightly lonk backup: sqlite-safe .backup copy -> restic -> rest-server on
# the tailnet Windows box (g1nd). Repo/bucket: rest:http://g1nd:8000/lonk.
# rest-server runs --no-auth: tailnet reachability + restic repo encryption
# gate access. Persistent=true catches runs missed while the box was down;
# a failed run (g1nd asleep) is retried at the next scheduled time.
{ config, pkgs, ... }: {
  sops.secrets.restic-password = { };

  systemd.services.lonk-backup = {
    description = "Backup lonk sqlite to g1nd restic REST server";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.restic pkgs.sqlite ];
    serviceConfig.Type = "oneshot";
    environment.RESTIC_REPOSITORY = "rest:http://g1nd:8000/lonk";
    script = ''
      set -eu
      export RESTIC_PASSWORD_FILE=${config.sops.secrets.restic-password.path}
      DB=$(ls /var/lib/rancher/k3s/storage/pvc-*_lonk_lonk-data/lonk.db)
      TMP=$(mktemp -d)
      trap 'rm -rf "$TMP"' EXIT
      sqlite3 "$DB" ".backup $TMP/lonk.db"
      restic cat config >/dev/null 2>&1 || restic init
      restic backup "$TMP/lonk.db" --tag lonk
      restic forget --keep-daily 14 --keep-weekly 8 --prune
    '';
  };

  systemd.timers.lonk-backup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:17:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
  };
}
