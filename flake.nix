{
  description = "My personal NUR repository";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        imports = [
          inputs.flake-parts.flakeModules.modules
        ];

        systems = [
          "x86_64-linux"
          "i686-linux"
          "x86_64-darwin"
          "aarch64-darwin"
          "aarch64-linux"
          "armv6l-linux"
          "armv7l-linux"
        ];
        perSystem =
          {
            self',
            pkgs,
            lib,
            ...
          }:
          {
            legacyPackages = (import ./default.nix { inherit pkgs; });

            packages = (
              let
                inherit pkgs;

                lpkgs = lib.filterAttrs (_: v: lib.isDerivation v) self'.legacyPackages;

                all = pkgs.symlinkJoin {
                  name = "all";
                  paths = (import ./ci.nix { inherit pkgs; }).cachePkgs;
                };
              in
              (
                lpkgs
                // {
                  inherit all;
                  default = all;
                }
              )
            );

            formatter = pkgs.nixfmt-tree;
          };
        flake = {
          overlays = {
            default = import ./overlay.nix;
          };

          modules = {
            nixos = {
              laminar = ./modules/nixos/laminar.nix;
            };
            darwin = {
              caddy = ./modules/darwin/caddy;
            };
          };
        };
      }
    );
}
