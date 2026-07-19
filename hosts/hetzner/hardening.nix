# Cloudflare ranges pinned from https://www.cloudflare.com/ips-v4 and /ips-v6
# (refresh when Cloudflare announces changes — rare)
{ private, ... }:
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
    # tailscale0: SSH + kubectl 6443 over the tailnet
    # cni0/flannel.1: k3s pod traffic must reach the host-side API/kubelet
    trustedInterfaces = [ "tailscale0" "cni0" "flannel.1" ];
    extraInputRules = ''
      ip  saddr { ${builtins.concatStringsSep ", " cfV4} } tcp dport { 80, 443 } accept
      ip6 saddr { ${builtins.concatStringsSep ", " cfV6} } tcp dport { 80, 443 } accept
    '';
    # k3s svclb DNATs 80/443 to traefik in PREROUTING, bypassing INPUT —
    # enforce CF-only on the forward path for WAN-ingress traffic too
    extraForwardRules = ''
      iifname "${private.interface}" ct original proto-dst { 80, 443 } ip  saddr != { ${builtins.concatStringsSep ", " cfV4} } drop
      iifname "${private.interface}" ct original proto-dst { 80, 443 } ip6 saddr != { ${builtins.concatStringsSep ", " cfV6} } drop
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
