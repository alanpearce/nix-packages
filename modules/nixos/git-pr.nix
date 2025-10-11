{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.services.git-pr;

  settingsFormat = pkgs.formats.toml { };
in
{
  options.services.git-pr = {
    enable = mkEnableOption "A pastebin supercharged for git collaboration.";

    package = mkPackageOption pkgs "git-pr" { };

    user = mkOption {
      type = types.str;
      default = "git-pr";
      description = "The user to use for git-pr.";
    };

    group = mkOption {
      type = types.str;
      default = "git-pr";
      description = "The group to use for git-pr.";
    };

    homeDir = mkOption {
      type = types.path;
      default = "/var/lib/git-pr";
      description = "The home directory for git-pr.";
    };

    settings = mkOption {
      default = { };

      description = ''
        Additional settings for git-pr.

        See https://github.com/picosh/git-pr/blob/main/git-pr.toml
      '';

      type = types.submodule {
        freeformType = settingsFormat.type;
        options = {
          url = mkOption {
            type = types.str;
            default = "localhost";
            description = "Used for help commands, exclude protocol.";
          };

          host = mkOption {
            type = types.str;
            default = "0.0.0.0";
            description = "Host to listen (web and ssh).";
          };

          ssh_port = mkOption {
            type = types.port;
            default = 2222;
            description = "Port to listen for ssh connections.";
          };

          web_port = mkOption {
            type = types.port;
            default = 3000;
            description = "Port to listen for web connections.";
          };

          data_dir = mkOption {
            type = types.path;
            default = "${cfg.homeDir}/data";
            description = "Where we store the sqlite db, this toml file, and ssh host keys.";
          };

          admins = mkOption {
            type = types.listOf (types.str);
            default = [ ];
            description = "List of admin ssh pubkeys, authorised to submit review and other admin permissions.";
          };

          time_format = mkOption {
            type = types.str;
            default = "2006-01-02";
            description = "Set datetime format for our clients. See https://pkg.go.dev/time#pkg-constants for explanation.";
          };

          create_repo = mkOption {
            type = types.enum [
              "admin"
              "user"
            ];
            default = "admin";
            description = "Who can create new repos?";
          };

          desc = mkOption {
            type = types.str;
            default = "";
            description = "Add a description box to the top of the index page, supports HTML.";
          };

          theme = mkOption {
            type = types.str;
            default = "dracula";
            description = "Set the theme for the web interface.";
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    users.users = optionalAttrs (cfg.user == "git-pr") {
      git-pr = {
        inherit (cfg) group;
        isSystemUser = true;
        home = cfg.homeDir;
        createHome = true;
      };
    };
    users.groups = optionalAttrs (cfg.group == "git-pr") {
      git-pr = { };
    };

    systemd.services.git-pr = {
      description = "A pastebin supercharged for git collaboration.";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig =
        let
          configFile = settingsFormat.generate "git-pr-config.toml" cfg.settings;
        in
        {
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.homeDir;
          ExecStart = "${cfg.package}/bin/git-pr --config ${configFile}";
          ExecStartPre = "${pkgs.coreutils}/bin/install -d -m 755 ${cfg.homeDir}/data";
          Restart = "always";
        };
    };
  };
}
