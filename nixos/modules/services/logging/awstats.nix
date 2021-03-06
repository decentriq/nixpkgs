{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.awstats;
  httpd = config.services.httpd;
  package = pkgs.awstats;
in

{
  options.services.awstats = {
    enable = mkOption {
      type = types.bool;
      default = cfg.service.enable;
      description = ''
        Enable the awstats program (but not service).
        Currently only simple httpd (Apache) configs are supported,
        and awstats plugins may not work correctly.
      '';
    };
    vardir = mkOption {
      type = types.path;
      default = "/var/lib/awstats";
      description = "The directory where variable awstats data will be stored.";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra configuration to be appendend to awstats.conf.";
    };

    updateAt = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "hourly";
      description = ''
        Specification of the time at which awstats will get updated.
        (in the format described by <citerefentry>
          <refentrytitle>systemd.time</refentrytitle>
          <manvolnum>7</manvolnum></citerefentry>)
      '';
    };

    service = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''Enable the awstats web service. This switches on httpd.'';
      };
      urlPrefix = mkOption {
        type = types.str;
        default = "/awstats";
        description = "The URL prefix under which the awstats service appears.";
      };
    };
  };


  config = mkIf cfg.enable {
    environment.systemPackages = [ package.bin ];
    /* TODO:
      - heed config.services.httpd.logPerVirtualHost, etc.
      - Can't AllowToUpdateStatsFromBrowser, as CGI scripts don't have permission
        to read the logs, and our httpd config apparently doesn't an option for that.
    */
    environment.etc."awstats/awstats.conf".source = pkgs.runCommand "awstats.conf"
      { preferLocalBuild = true; }
      ( let
          logFormat =
            if httpd.logFormat == "combined" then "1" else
            if httpd.logFormat == "common" then "4" else
            throw "awstats service doesn't support Apache log format `${httpd.logFormat}`";
        in
        ''
          sed \
            -e 's|^\(DirData\)=.*$|\1="${cfg.vardir}"|' \
            -e 's|^\(DirIcons\)=.*$|\1="icons"|' \
            -e 's|^\(CreateDirDataIfNotExists\)=.*$|\1=1|' \
            -e 's|^\(SiteDomain\)=.*$|\1="${httpd.hostName}"|' \
            -e 's|^\(LogFile\)=.*$|\1="${httpd.logDir}/access_log"|' \
            -e 's|^\(LogFormat\)=.*$|\1=${logFormat}|' \
            < '${package.out}/wwwroot/cgi-bin/awstats.model.conf' > "$out"
          echo '${cfg.extraConfig}' >> "$out"
        '');

    systemd.tmpfiles.rules = optionals cfg.service.enable [
      "d '${cfg.vardir}' - ${httpd.user} ${httpd.group} - -"
      "Z '${cfg.vardir}' - ${httpd.user} ${httpd.group} - -"
    ];

    # The httpd sub-service showing awstats.
    services.httpd = optionalAttrs cfg.service.enable {
      enable = true;
      extraConfig = ''
        Alias ${cfg.service.urlPrefix}/classes "${package.out}/wwwroot/classes/"
        Alias ${cfg.service.urlPrefix}/css "${package.out}/wwwroot/css/"
        Alias ${cfg.service.urlPrefix}/icons "${package.out}/wwwroot/icon/"
        ScriptAlias ${cfg.service.urlPrefix}/ "${package.out}/wwwroot/cgi-bin/"

        <Directory "${package.out}/wwwroot">
          Options None
          Require all granted
        </Directory>
      '';
    };

    systemd.services.awstats-update = mkIf (cfg.updateAt != null) {
      description = "awstats log collector";
      script = "exec '${package.bin}/bin/awstats' -update -config=awstats.conf";
      startAt = cfg.updateAt;
    };
  };

}

