# Cloudflare ranges pinned from https://www.cloudflare.com/ips-v4 and /ips-v6
# (refresh when Cloudflare announces changes — rare)
{ ... }:
let
  cfV4 = [
    "173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22" "103.31.4.0/22"
    "141.101.64.0/18" "108.162.192.0/18" "190.93.240.0/20" "188.114.96.0/20"
    "197.234.240.0/22" "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/13"
    "104.24.0.0/14" "172.64.0.0/13" "131.0.72.0/22"
  ];
  cfV6 = [
    "2400:cb00::/32" "2606:4700::/32" "2803:f800::/32" "2405:b500::/32"
    "2405:8100::/32" "2a06:98c0::/29" "2c0f:f248::/32"
  ];
in {
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ]; # REMOVE after Tailscale verified (plan Task 10 step 5)
    trustedInterfaces = [ "tailscale0" ]; # SSH + kubectl 6443 over the tailnet
    extraInputRules = ''
      ip  saddr { ${builtins.concatStringsSep ", " cfV4} } tcp dport { 80, 443 } accept
      ip6 saddr { ${builtins.concatStringsSep ", " cfV6} } tcp dport { 80, 443 } accept
    '';
  };

  services.fail2ban.enable = true;
  services.smartd = {
    enable = true;
    notifications.wall.enable = true;
  };
  system.autoUpgrade.enable = false; # deliberate rebuilds from the flake instead
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
}
