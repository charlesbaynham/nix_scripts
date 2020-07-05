let
  pkgs = import <nixpkgs> {};
  zc706 = import <zc706> { mozillaOverlay = import <mozillaOverlay>; };
  artiq-zynq = import <artiq-zynq> { mozillaOverlay = import <mozillaOverlay>; };
  artiq-fast = import <artiq-fast> { inherit pkgs; };
  addBuildProducts = drv: drv.overrideAttrs (oldAttrs: {
      installPhase = ''
        ${oldAttrs.installPhase}
        mkdir -p $out/nix-support
        for f in $out/*.elf ; do
          echo file binary-dist $f >> $out/nix-support/hydra-build-products
        done
      '';
    });
in
  (
    builtins.mapAttrs (name: drv:
      pkgs.lib.hydraJob (
        addBuildProducts drv
      )
    ) zc706.zc706
  ) // (
    builtins.mapAttrs (key: value: pkgs.lib.hydraJob value) artiq-zynq
  ) // {
    zc706-hitl-tests = pkgs.lib.hydraJob (pkgs.stdenv.mkDerivation {
      name = "zc706-hitl-tests";

      # requires patched Nix
      __networked = true;

      buildInputs = [
        pkgs.openssh pkgs.rsync artiq-fast.artiq
      ];
      phases = [ "buildPhase" ];

      buildPhase =
        ''
        export USER=hydra
        pushd ${<artiq-zynq>}
        bash ${<artiq-zynq>}/remote_run.sh -h rpi-4 -o "-F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i /opt/hydra_id_rsa" -d ${artiq-zynq.zc706-simple-jtag}
        popd

        sleep 15

        artiq_run --device-db ${<artiq-zynq>}/examples/device_db.py ${<artiq-zynq>}/examples/mandelbrot.py

        touch $out

        echo Completed
        '';
    });
  }
