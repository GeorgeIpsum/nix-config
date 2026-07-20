# Nightly lonk backup: sqlite-safe .backup copy -> restic -> rest-server on
# a tailnet device (endpoint in nix-private — public repo carries no tailnet names).
# rest-server runs --no-auth: tailnet reachability + restic repo encryption
# gate access. Persistent=true catches runs missed while the box was down;
# a failed run (g1nd asleep) is retried at the next scheduled time.
{ config, pkgs, private, ... }: {
  sops.secrets.restic-password = { };

  systemd.services.lonk-backup = {
    description = "Backup lonk sqlite to g1nd restic REST server";
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.restic pkgs.sqlite ];
    serviceConfig.Type = "oneshot";
    environment.RESTIC_REPOSITORY = private.backupTarget;
    script = ''
      set -eu
      export RESTIC_PASSWORD_FILE=${config.sops.secrets.restic-password.path}
      DB=$(ls /var/lib/rancher/k3s/storage/pvc-*_lonk_lonk-data/lonk.db)
      TMP=$(mktemp -d)
      trap 'rm -rf "$TMP"' EXIT
      sqlite3 "$DB" ".backup $TMP/lonk.db"
      VW=$(ls /var/lib/rancher/k3s/storage/pvc-*_vaultwarden_vaultwarden-data/db.sqlite3 2>/dev/null || true)
      [ -n "$VW" ] && sqlite3 "$VW" ".backup $TMP/vaultwarden.db"
      PGD=$(ls -d /var/lib/rancher/k3s/storage/pvc-*_ebloved_ebloved-pgdump 2>/dev/null || true)
      [ -n "$PGD" ] && cp "$PGD"/*.dump "$TMP"/ 2>/dev/null || true
      restic cat config >/dev/null 2>&1 || restic init
      restic backup "$TMP" --tag homelab
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
