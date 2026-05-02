{
  description = "Reproducible and Immutable NixOS Images";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    evident-instance = {
      url = "gitlab:dpss-inesc-id/achilles-cvm/dev?dir=instance";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
    evident-client = {
      url = "gitlab:dpss-inesc-id/achilles-cvm/dev?dir=client";
    };
  };
  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "riscv64-linux"
      ];
      perSystem = { config, pkgs, ... }: {
        packages =
        let
          mkBundle = inputs.evident-instance.apps.x86_64-linux.mkBundle;
        in
        {
          root-ca = pkgs.callPackage ./src {
            platform = "gce";
            inherit inputs;
            evidentInstancePackage = mkBundle {
              mandatoryFeature = "snp_gce";
              optionalFeatures = [
                "debug"
              ];
            };
            evidentClientPackage = inputs.evident-client.packages.x86_64-linux.evident;
            withDebug = true;
          };
          intermediate-ca-ec2 = pkgs.callPackage ./src {
            platform = "ec2";
            inherit inputs;
            evidentInstancePackage = mkBundle {
              mandatoryFeature = "snp_ec2";
              optionalFeatures = [
                "debug"
                "request_certificate"
              ];
              certificateIssuerEndpoint = "root-ca.evident.joaohs.com:5010";
            };
            evidentClientPackage = inputs.evident-client.packages.x86_64-linux.evident;
            withDebug = true;
          };
          intermediate-ca-gce = pkgs.callPackage ./src {
            platform = "gce";
            inherit inputs;
            evidentInstancePackage = mkBundle {
              mandatoryFeature = "snp_gce";
              optionalFeatures = [
                "debug"
                "request_certificate"
              ];
              certificateIssuerEndpoint = "root-ca.evident.joaohs.com:5010";
            };
            evidentClientPackage = inputs.evident-client.packages.x86_64-linux.evident;
            withDebug = true;
          };
        };
      };
    };
}
