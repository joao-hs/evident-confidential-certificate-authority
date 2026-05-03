{
  pkgs,
  evidentClientPackage,
  ...
}:
let
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

    exec ${evidentClientPackage}/bin/evident serve-certify ${"$"}cert ${instanceKey} --grpc-cert ${grpcCert} --grpc-key ${grpcKey}
  '';
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/evident 0755 root root -"
    "d /var/lib/evident/pwd 0755 root root -"
  ];

  environment.etc."evident/trusted-keys" = {
    source = ./trusted-keys;
  };

  systemd.services.confidential-ca = {
    description = "Confidential Certificate Authority";
    after = [ "evident-server.service" ];
    requires = [ "evident-server.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${startScript}";
      WorkingDirectory = "/var/lib/evident/pwd";
      User = "root";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStartSec = "0";
    };
  };

  networking.firewall.allowedTCPPorts = [
    5010
  ];
}
