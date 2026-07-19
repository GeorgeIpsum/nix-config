{ config, lib, private, ... }: {
  imports = [ ./disko.nix ./hardening.nix ./k3s.nix ./backup.nix ];

  networking.hostName = "hetzner";
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

  networking.useDHCP = true; # Hetzner dedicated IPv4 via DHCP
  networking.interfaces.${private.interface}.ipv6.addresses = [
    { address = private.ipv6Address; prefixLength = 64; }
  ];
  networking.defaultGateway6 = {
    address = private.ipv6Gateway;
    interface = private.interface;
  };

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

  system.stateVersion = "25.11";
}
