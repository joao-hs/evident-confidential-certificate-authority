{ lib, ... }:
let
  keysDir = ./trusted-keys;
  keyFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".asc" name
  ) (builtins.readDir keysDir);
  linkCommands = lib.concatStringsSep "\n" (lib.mapAttrsToList (
    name: _: "ln -sfn ${keysDir}/${name} \"$out/srv/evident/trusted-keys/${name}\""
  ) keyFiles);
in
{
  system.extraSystemBuilderCmds = ''
    mkdir -p "$out/srv/evident/trusted-keys"
    ${linkCommands}
  '';
}
