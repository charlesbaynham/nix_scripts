# This runs `run-test.nix` with `nix-build`

{ pkgs ? import <nixpkgs> {},
  diskImage ? "/opt/windows/c.img",
  qemuMem ? "2G",
  testTimeout ? 180,
}:

with pkgs;

let
  windowsRunner = overrides:
    import ./run-test.nix ({
      inherit pkgs diskImage qemuMem testTimeout;
    } // overrides);
in

stdenv.mkDerivation {
  name = "windows-test";
  src = null;

  phases = [ "installPhase" "checkPhase" ];
  installPhase = "touch $out";
  doCheck = true;
  checkPhase = ''
    ${windowsRunner { testCommand = "set ARTIQ_ROOT=%cd%\\anaconda\\envs\\artiq-env\\Lib\\site-packages\\artiq\\examples\\kc705_nist_clock&&python -m unittest discover -v artiq.test"; }}/bin/run.sh
  '';
}
