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
in
{
  users.users.${username} = {
    createHome = false;
    isSystemUser = true;
    group = "${username}";
    shell = "${pkgs.shadow}/bin/nologin";
  };
  users.groups.ca = {};

  systemd.services.confidential-ca = {
    description = "Confidential Certificate Authority";
    after = [ "evident-server.service" ];
    requires = [ "evident-server.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${startScript}";
      WorkingDirectory = "/var/lib/${username}";
      User = "root";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "0";
    };
  };

}
