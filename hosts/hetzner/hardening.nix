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
    openFirewall = false; # SSH via tailnet only (tailscale0 is trusted)
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  networking.nftables.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ ]; # SSH via tailnet only
    # tailscale0: SSH + kubectl 6443 over the tailnet
    # cni0/flannel.1: k3s pod traffic must reach the host-side API/kubelet
    trustedInterfaces = [ "tailscale0" "cni0" "flannel.1" ];
    extraInputRules = ''
      ip  saddr { ${builtins.concatStringsSep ", " cfV4} } tcp dport { 80, 443 } accept
      ip6 saddr { ${builtins.concatStringsSep ", " cfV6} } tcp dport { 80, 443 } accept
    '';
    filterForward = true;
    # trustedInterfaces only affects INPUT; the forward chain default-drops
    # non-DNAT new connections, which kills pod->pod-IP dials (traefik->endpoints).
    extraForwardRules = ''
      iifname { "cni0", "flannel.1", "tailscale0" } accept
    '';
  };

  # k3s svclb DNATs 80/443 to traefik in PREROUTING, bypassing INPUT, and the
  # nixos-fw forward chain accepts ALL DNATed traffic ("ct status dnat accept")
  # before extraForwardRules run. Enforce CF-only in a separate chain hooked at
  # higher priority (-5 < filter 0) — a drop here is final. Extend the port set
  # if future workloads expose more hostPorts.
  networking.nftables.tables."cf-only-ingress" = {
    family = "inet";
    content = ''
      chain forward-early {
        type filter hook forward priority -5; policy accept;
        iifname "${private.interface}" ct original proto-dst { 80, 443 } ip  saddr != { ${builtins.concatStringsSep ", " cfV4} } drop
        iifname "${private.interface}" ct original proto-dst { 80, 443 } ip6 saddr != { ${builtins.concatStringsSep ", " cfV6} } drop
      }
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
