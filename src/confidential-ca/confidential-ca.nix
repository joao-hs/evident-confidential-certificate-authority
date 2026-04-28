{
  pkgs,
  evidentClientPackage,
  ...
}:
let
  username="ca";
  port="5010";
  grpcCert="/etc/evident/pki/grpc/public/grpc.crt.pem";
  grpcKey="/etc/evident/pki/grpc/private/grpc.key.pem";
  selfSignedCert="/etc/evident/pki/instance/public/instance-root.crt.pem";
  chainedCert="/etc/evident/pki/instance/public/instance.crt.pem";
  instanceKey="/etc/evident/pki/instance/private/instance.key.der";
  startScript = pkgs.writeShellScript "confidential-ca-start" ''
    if [ -f ${chainedCert} ]; then
      cert=${chainedCert}
    else
      cert=${selfSignedCert}
    fi

    exec ${evidentClientPackage}/bin/evident ${port} ${"$"}cert ${instanceKey} ${grpcCert} ${grpcKey}
  '';
  gpgSetupScript = pkgs.writeShellScript "confidential-ca-gpg-setup" ''
    set -euo pipefail

    trusted_dir="/srv/evident/trusted-keys"
    GNUPGHOME="/var/lib/evident/${username}/gnupg"
    keyring_dir="/var/lib/evident/keyring"
    keyring="${"$"}keyring_dir/keyring.kbx"

    ${pkgs.coreutils}/bin/install -m 755 -d "${"$"}trusted_dir"
    ${pkgs.coreutils}/bin/install -m 755 -d "/var/lib/evident"
    ${pkgs.coreutils}/bin/install -m 755 -d "/var/lib/evident/${username}"
    ${pkgs.coreutils}/bin/install -m 700 -d "${"$"}GNUPGHOME"
    ${pkgs.coreutils}/bin/install -m 700 -d "${"$"}keyring_dir"

    key_files="$(${pkgs.findutils}/bin/find "${"$"}trusted_dir" -maxdepth 1 -type f \( -name '*.asc' -o -name '*.gpg' -o -name '*.pgp' -o -name '*.key' \) -print)"
    if [ -n "${"$"}key_files" ]; then
      ${pkgs.gnupg}/bin/gpg --homedir "${"$"}GNUPGHOME" --batch --no-default-keyring --keyring "${"$"}keyring" --import ${"$"}key_files

      ${pkgs.gnupg}/bin/gpg --homedir "${"$"}GNUPGHOME" --batch --no-default-keyring --keyring "${"$"}keyring" --with-colons --list-keys \
        | ${pkgs.gawk}/bin/awk -F: '$1=="fpr"{print $10":6:"}' \
        | ${pkgs.gnupg}/bin/gpg --homedir "${"$"}GNUPGHOME" --batch --import-ownertrust

      ${pkgs.coreutils}/bin/chown root:${username} "${"$"}keyring_dir" "${"$"}keyring"
      ${pkgs.coreutils}/bin/chmod 750 "${"$"}keyring_dir"
      ${pkgs.coreutils}/bin/chmod 640 "${"$"}keyring"
    fi
  '';
in
{
  imports = [ ./trusted-keys.nix ];
  users.users.${username} = {
    createHome = false;
    isSystemUser = true;
    group = "${username}";
    shell = "${pkgs.shadow}/bin/nologin";
  };
  users.groups.${username} = {};

  systemd.tmpfiles.rules = [
    "d /var/lib/evident 0755 root ${username} -"
    "d /var/lib/evident/${username} 0755 ${username} ${username} -"
    "d /var/lib/evident/${username}/gnupg 0700 ${username} ${username} -"
    "d /var/lib/evident/keyring 0770 root ${username} -"
  ];

  systemd.services.confidential-ca = {
    description = "Confidential Certificate Authority";
    after = [ "evident-server.service" ];
    requires = [ "evident-server.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      PermissionsStartOnly = true;
      ExecStartPre = "${gpgSetupScript}";
      ExecStart = "${startScript}";
      Environment = [ "GNUPGHOME=/var/lib/evident/${username}/gnupg" ];
      WorkingDirectory = "/var/lib/${username}";
      User = "${username}";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "0";
    };
  };

}
