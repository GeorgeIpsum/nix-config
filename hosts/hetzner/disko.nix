# 2x Samsung 512GB NVMe + BIOS boot confirmed in rescue (Task 9).
# Separate ext4 /boot per disk: GRUB's ZFS reader can't handle modern pool
# feature flags, so the kernel must live off-pool. (Attr names keep gpt order:
# bios < boot < zfs alphabetically.)
{ ... }: {
  disko.devices = {
    disk.a = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          bios = { size = "1M"; type = "EF02"; };
          boot = {
            size = "1G";
            content = { type = "filesystem"; format = "ext4"; mountpoint = "/boot"; };
          };
          zfs = { size = "100%"; content = { type = "zfs"; pool = "rpool"; }; };
        };
      };
    };
    disk.b = {
      type = "disk";
      device = "/dev/nvme1n1";
      content = {
        type = "gpt";
        partitions = {
          bios = { size = "1M"; type = "EF02"; };
          boot = {
            size = "1G";
            content = { type = "filesystem"; format = "ext4"; mountpoint = "/boot2"; };
          };
          zfs = { size = "100%"; content = { type = "zfs"; pool = "rpool"; }; };
        };
      };
    };
    zpool.rpool = {
      type = "zpool";
      mode = "mirror";
      rootFsOptions = {
        compression = "zstd";
        acltype = "posixacl";
        xattr = "sa";
        atime = "off";
        mountpoint = "none";
      };
      datasets = {
        root = { type = "zfs_fs"; mountpoint = "/"; };
        nix = { type = "zfs_fs"; mountpoint = "/nix"; };
        home = { type = "zfs_fs"; mountpoint = "/home"; };
        # ext4 zvol: k3s containerd avoids the zfs snapshotter
        rancher = {
          type = "zfs_volume";
          size = "200G";
          content = { type = "filesystem"; format = "ext4"; mountpoint = "/var/lib/rancher"; };
        };
      };
    };
  };
}
