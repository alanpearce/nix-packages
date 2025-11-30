{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib) types;

  cfg = config.services.goaccess;

  # Helper function to generate a configuration file from the settings module
  settingsFormat = pkgs.formats.keyValue {
    mkKeyValue = pkgs.lib.generators.mkKeyValueDefault {} " ";
    listsAsDuplicateKeys = true;
  };

  instanceName = name: "goaccess@${name}";

  enabledInstances = lib.filterAttrs (name: conf: conf.enable) config.services.goaccess.instances;
in
{
  options.services.goaccess = {
    package = lib.mkPackageOption pkgs "goaccess" { };

    user = lib.mkOption {
      type = types.str;
      default = "goaccess";
      description = "User to run goaccess service as";
    };

    group = lib.mkOption {
      type = types.str;
      default = "goaccess";
      description = "Group to run goaccess service as";
    };

    instances = lib.mkOption {
      type = with types; attrsOf (submodule ({ config, name, ... }: {
        options = {
          enable = lib.mkEnableOption "goaccess web log analyzer service";

          # Timer configuration for non-real-time mode
          dates = lib.mkOption {
            type = with types; nullOr str;
            default = null;
            example = "daily";
            description = ''
              Systemd timer specification for periodic report generation.
              Only applies when real-time HTML is disabled.
              Examples: "daily", "hourly", "*-*-* 06:00:00" (at 6 AM every day)
            '';
          };

          # RFC42-compatible settings module
          settings = lib.mkOption {
            type = types.submodule {
              freeformType = settingsFormat.type;
              options = {
                # Basic configuration
                log-file = lib.mkOption {
                  type = with types; either path (listOf path);
                  default = "/var/log/nginx/access.log";
                  description = "Path to the web server access log file to analyze";
                };

                output = lib.mkOption {
                  type = types.path;
                  default = "/var/www/html/goaccess/report.html";
                  description = "Path for the output HTML report";
                };

                # Mode selection
                real-time-html = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Enable real-time HTML output with WebSocket support";
                };

                # Log format configuration
                log-format = lib.mkOption {
                  type = types.str;
                  default = "COMBINED";
                  description = ''
                    Log format specification. Can be a predefined format name
                    (COMBINED, COMMON, VCOMBINED, etc.) or a custom format string.
                  '';
                };

                ignore-crawlers = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Ignore crawlers/bots from statistics";
                };

                anonymize-ip = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Anonymize client IP addresses for privacy";
                };

                anonymize-level = lib.mkOption {
                  type = types.enum [
                    1
                    2
                    3
                  ];
                  default = 1;
                  description = "IP anonymization level (1=default, 2=strong, 3=pedantic)";
                };

                # Persistence options
                persist = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Persist parsed data to disk for incremental processing";
                };

                restore = lib.mkOption {
                  type = types.bool;
                  default = false;
                  description = "Load previously stored data from disk";
                };

                db-path = lib.mkOption {
                  type = types.path;
                  default = "/var/lib/goaccess/${name}";
                  description = "Path for on-disk database files";
                };

                keep-last = lib.mkOption {
                  type = with types; nullOr int;
                  default = null;
                  description = "Keep only the last N days in storage (enables data recycling)";
                };

                # Process configuration
                jobs = lib.mkOption {
                  type = types.int;
                  default = 1;
                  description = "Number of parallel processing threads (1-6)";
                };

                chunk-size = lib.mkOption {
                  type = types.int;
                  default = 4096;
                  description = "Number of lines per chunk for parallel processing (256-32768)";
                };

                # Server configuration for real-time mode
                unix-socket = lib.mkOption {
                  type = with types; nullOr str;
                  default = null;
                  example = "/run/goaccess.sock";
                };

                port = lib.mkOption {
                  type = types.port;
                  default = 7890;
                  description = "Port for the WebSocket server (real-time mode only)";
                };

                addr = lib.mkOption {
                  type = with types; nullOr str;
                  default = "0.0.0.0";
                  description = "IP address to bind the WebSocket server to";
                };

                # WebSocket URL for real-time mode
                ws-url = lib.mkOption {
                  type = with types; nullOr str;
                  default = null;
                  description = ''
                    URL for WebSocket connection (useful when running behind proxy).
                    If not set, defaults to the generated report's hostname.
                  '';
                };
              };
            };
            default = { };
            description = ''
              RFC42-compatible settings for goaccess configuration file.
              These options will be written to a configuration file and passed to GoAccess via --config-file.
              See https://goaccess.io/man for all available options.
            '';
            example = {
              log-file = "/var/log/nginx/access.log";
              output = "/var/www/html/goaccess/report.html";
              log-format = "COMBINED";
              html-report-title = "My Server Analytics";
              ignore-crawlers = true;
              anonymize-ip = true;
            };
          };
        };
      }));
      default = { };
      description = "GoAccess web log analyzer service instances";
      example = {
        web-logs = {
          enable = true;
          settings = {
            log-file = "/var/log/nginx/access.log";
            output = "/var/www/html/goaccess/web-logs.html";
            real-time-html = true;
            port = 7890;
          };
        };
        api-logs = {
          enable = true;
          dates = "daily";
          settings = {
            log-file = "/var/log/nginx/api-access.log";
            output = "/var/www/html/goaccess/api-logs.html";
            html-report-title = "API Analytics";
          };
        };
      };
    };
  };

  config = lib.mkIf (enabledInstances != { }) (lib.mkMerge [
    {
      environment.systemPackages = [ cfg.package ];

      # Create user and group if needed
      users.users.goaccess = lib.mkIf (cfg.user == "goaccess") {
        isSystemUser = true;
        group = cfg.group;
        home = "/var/lib/goaccess";
        createHome = true;
      };

      users.groups.goaccess = lib.mkIf (cfg.group == "goaccess") { };
    }

    # Generate systemd services for all enabled instances
    {
      systemd.services = lib.mapAttrs' (
        name: instanceCfg:
        let
          configFile = settingsFormat.generate name instanceCfg.settings;
          realTime = instanceCfg.settings.real-time-html or false;
        in
        lib.nameValuePair (instanceName name) {
          description = "GoAccess Web Log Analyzer (${name})";
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = if realTime then "simple" else "oneshot";
            ExecStart = "${cfg.package}/bin/goaccess --config-file=${configFile}";
            ExecStartPre = "+" + pkgs.writeShellScript "goaccess-${name}-prep" ''
              install -d -o ${cfg.user} -g ${cfg.group} ${dirOf instanceCfg.settings.output}
            '';
            User = cfg.user;
            Group = cfg.group;
            Restart = lib.mkIf realTime "on-failure";
            # Ensure directories exist and have correct permissions
            StateDirectory = "goaccess/${name}";
            RuntimeDirectory = "goaccess";
            RuntimeDirectoryMode = "750";
            # Security settings
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadOnlyPaths =  (lib.flatten instanceCfg.settings.log-file);
            ReadWritePaths = [
              (instanceCfg.settings.db-path)
              (dirOf instanceCfg.settings.output)
              "/run/goaccess/"
            ];
          };
        }
      ) enabledInstances;

      systemd.timers = lib.mapAttrs' (
        name: instanceCfg: (lib.nameValuePair (instanceName name) {
          description = "Timer for GoAccess report generation (${name})";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = instanceCfg.dates;
            Persistent = true;
          };
        })
      ) (lib.filterAttrs (_: icfg: icfg.dates != null) enabledInstances);

      systemd.tmpfiles.rules = lib.flatten (lib.mapAttrsToList
      (name: icfg: [
        "d ${icfg.settings.db-path} 1700 ${cfg.user} ${cfg.group} -"
        "d ${(dirOf icfg.settings.output)} 1700 ${cfg.user} ${cfg.group}} -"
      ])
      (lib.filterAttrs (_: icfg: icfg.settings.persist || icfg.settings.restore) enabledInstances));
    }

    # Generate assertions for all enabled instances
    {
      assertions = lib.mapAttrsToList ( name: instanceCfg: {
         assertion = (instanceCfg.settings.real-time-html or false) != (instanceCfg.dates != null);
         message = ''
           services.goaccess.instances.${name}: Exactly one of real-time-html or dates must be specified.
           - Set real-time-html to true for real-time HTML output with WebSocket support.
           - Set dates to a timer specification for periodic static report generation.
         '';
       }) enabledInstances;
    }
  ]);
}
