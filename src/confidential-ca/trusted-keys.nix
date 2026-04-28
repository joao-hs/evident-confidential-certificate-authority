{ lib, ... }:
let
  keysDir = ./trusted-keys;
  keyFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".pub.asc" name
  ) (builtins.readDir keysDir);
  keyLinks = lib.mapAttrsToList (
    name: _: "L+ /srv/evident/trusted-keys/${name} - - - - ${keysDir}/${name}"
  ) keyFiles;
in
{
  systemd.tmpfiles.rules = [
    "d /srv/evident 0755 root root -"
    "d /srv/evident/trusted-keys 0755 root root -"
  ] ++ keyLinks;
}
