{
  description = "My personal NUR repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    files.url = "github:mightyiam/files";
    git-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        imports = [
          inputs.flake-parts.flakeModules.modules
          inputs.files.flakeModules.default
          inputs.git-hooks.flakeModule
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
            config,
            ...
          }:
          let
            inherit pkgs;

            lpkgs = lib.filterAttrs (_: v: lib.isDerivation v) self'.legacyPackages;

            all = pkgs.symlinkJoin {
              name = "all";
              paths = (import ./ci.nix { inherit pkgs; }).cachePkgs;
            };
          in
          {
            legacyPackages = (import ./default.nix { inherit pkgs; });

            packages = (
              lpkgs
              // {
                inherit all;
                default = all;
              }
            );

            formatter = pkgs.nixfmt-tree;

            devShells.default = pkgs.mkShell {
              packages = [
                config.files.writer.drv
                config.pre-commit.settings.package
              ]
              ++ config.pre-commit.settings.enabledPackages;

              shellHook = ''
                ${config.pre-commit.installationScript}
              '';
            };

            pre-commit = {
              check.enable = true;
              settings.hooks.gen-files = {
                enable = true;
                name = "Generate files from the files flake-parts module";
                files = "\\.nix$";
                excludes = [
                  "ci.nix"
                  "overlay.nix"
                ];
                pass_filenames = false;
                entry =
                  let
                    inherit (config.files.writer) drv exeFilename;
                  in
                  "${drv}/bin/${exeFilename}";
              };
            };

            files.files = [
              {
                path_ = "README.md";
                drv =
                  let
                    inherit (lib) mapAttrsToList concatStringsSep;
                    ps = lib.filterAttrs (k: v: (k != "all") && (lib.isDerivation v)) lpkgs;

                    plist = mapAttrsToList (name: p: ''
                      ### ${name}
                      - Version: ${p.version}
                      - Homepage: ${p.meta.homepage}
                      - Description: ${p.meta.description}
                    '') ps;

                    mkModuleList = mapAttrsToList (
                      mod: _: ''
                        - ${mod}
                      ''
                    );
                  in
                  pkgs.writeText "README.md" ''
                    # nix-packages

                    **My personal [NUR](https://github.com/nix-community/NUR) repository**

                    ## Packages
                    ${concatStringsSep "\n" plist}
                    ## Modules
                    ### NixOS
                    ${concatStringsSep "\n" (mkModuleList self.outputs.modules.nixos)}
                    ### Darwin
                    ${concatStringsSep "\n" (mkModuleList self.outputs.modules.darwin)}
                  '';
              }
            ];
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
