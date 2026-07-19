{
  description = "NixOS configs";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-private.url = "git+ssh://git@github.com/GeorgeIpsum/nix-private";
  };
  outputs = { nixpkgs, disko, sops-nix, nix-private, ... }: {
    nixosConfigurations.hetzner = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { private = nix-private.hosts.hetzner; };
      modules = [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        ./hosts/hetzner
      ];
    };
  };
}
