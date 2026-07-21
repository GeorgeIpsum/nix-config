{ config, lib, private, ... }: {
  imports = [ ./disko.nix ./hardening.nix ./k3s.nix ./backup.nix ];

  networking.hostName = "ebloved";
  networking.hostId = "8425e349"; # required by ZFS; any fixed 8-hex-digit value
  boot.loader.grub = {
    enable = true;
    mirroredBoots = [
      { devices = [ "/dev/nvme0n1" ]; path = "/boot"; }
      { devices = [ "/dev/nvme1n1" ]; path = "/boot2"; }
    ];
    # neutralize disko's EF02-derived devices so they don't duplicate mirroredBoots
    devices = lib.mkForce [ ];
  };
  boot.supportedFilesystems = [ "zfs" ];

  # Static IPv4 — Hetzner dedicated hands out a fixed IP, and DHCP lease
  # renewal proved fragile (lease expired → dhcpcd tore down the default
  # route → IPv4 egress died while inbound/tailnet kept working). Static
  # config removes the lease dependency entirely. Values from nix-private.
  networking.useDHCP = false;
  networking.interfaces.${private.interface} = {
    ipv4.addresses = [
      { address = private.ipv4; prefixLength = private.ipv4PrefixLength; }
    ];
    ipv6.addresses = [
      { address = private.ipv6Address; prefixLength = 64; }
    ];
  };
  networking.defaultGateway = {
    address = private.ipv4Gateway;
    interface = private.interface;
  };
  networking.defaultGateway6 = {
    address = private.ipv6Gateway;
    interface = private.interface;
  };
  # DHCP previously supplied resolvers; set them explicitly for static config.
  networking.nameservers = [ "185.12.64.1" "185.12.64.2" "1.1.1.1" ];

  services.zfs.autoScrub.enable = true;

  users.users.ibrahim = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG1NhNbbvXtGDXCx5tRW6YgRgZ5dsYvWGTtQ28SaXIvu g1n@Mac"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  sops.defaultSopsFile = ../../secrets/hetzner.yaml;
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.tailscale-authkey = { };

  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets.tailscale-authkey.path;
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.11";
}
