{ config, pkgs, lib, ... }:

with import <home-manager/modules/lib/dag.nix> { inherit lib; };
with lib;
with builtins;

let
  cfg = config.programs.docker;

  package = pkgs.stdenv.mkDerivation rec {
    name = "Docker.app";
    src = pkgs.fetchurl {
      url = "https://download.docker.com/mac/stable/1.12.1.12133/Docker.dmg";
      sha256 = "13qamjb9g1k093i2fn1x5dqlfq828w1zqyww6k9m0xpckd5fd2j8";
    };

    buildInputs = [ pkgs.undmg ];
    installPhase = ''
      source $stdenv/setup
      mkdir -pv $out/Applications/Docker.app
      cp -r ./* $out/Applications/Docker.app
    '';

    meta = {
      description = "Docker for Mac";
      homepage = https://docs.docker.com/docker-for-mac/;
      platforms = stdenv.lib.platforms.darwin;
    };
  };

in {

  options = {
    programs.docker.enable = mkEnableOption "Docker";
  };

  config = mkIf cfg.enable {
    home.packages = [ package ];
    home.activation.docker = dagEntryAfter["installPackages"] (let
      home = config.home.homeDirectory;
      applications = "${home}/.nix-profile/Applications";
      source = "${applications}/Docker.app";
      target = "${home}/Applications";
    in ''
      if [ -e ${target}/Docker.app ]; then
        rm -r ${target}/Docker.app
      fi
      osascript << EOF
        tell application "Finder"
        set mySource to POSIX file "${source}" as alias
        make new alias to mySource at POSIX file "${target}"
        set name of result to "Docker.app"
      end tell
      EOF

      echo "\nNeed root to install Docker for Mac..."
      sudo cp ${package}/Applications/Docker.app/Contents/Library/LaunchServices/com.docker.vmnetd /Library/PrivilegedHelperTools
      sudo cp ${package}/Applications/Docker.app/Contents/Resources/com.docker.vmnetd.plist /Library/LaunchDaemons/
      sudo chmod 544 /Library/PrivilegedHelperTools/com.docker.vmnetd
      sudo chmod 644 /Library/LaunchDaemons/com.docker.vmnetd.plist
      sudo launchctl load /Library/LaunchDaemons/com.docker.vmnetd.plist
      open -a ${source} --hide

      until docker version
      do
        sleep 1
      done
    '');
  };
}
