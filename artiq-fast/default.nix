{ pkgs ? import <nixpkgs> {}}:
with pkgs;
let
  pythonDeps = import ./pkgs/python-deps.nix { inherit (pkgs) stdenv fetchFromGitHub python3Packages; };

  boards = [
    { target = "kasli"; variant = "tester"; }
    { target = "kc705"; variant = "nist_clock"; }
  ];
  boardPackages = pkgs.lib.lists.foldr (board: start:
    let
      boardBinaries = import ./artiq-board.nix { inherit pkgs; } {
        target = board.target;
        variant = board.variant;
      };
    in
      start // {
        "artiq-board-${board.target}-${board.variant}" = boardBinaries;
      }) {} boards;
  mainPackages = rec {
    inherit (pythonDeps) sipyco asyncserial pythonparser pyqtgraph-qt5 misoc migen microscope jesd204b migen-axi lit outputcheck;
    binutils-or1k = callPackage ./pkgs/binutils.nix { platform = "or1k"; target = "or1k-linux"; };
    binutils-arm = callPackage ./pkgs/binutils.nix { platform = "arm"; target = "armv7-unknown-linux-gnueabihf"; };
    llvm-or1k = callPackage ./pkgs/llvm-or1k.nix {};
    rustc = callPackage ./pkgs/rust/rustc-with-crates.nix
      ((stdenv.lib.optionalAttrs (stdenv.cc.isGNU && stdenv.hostPlatform.isi686) {
         stdenv = overrideCC stdenv gcc6; # with gcc-7: undefined reference to `__divmoddi4'
       }) //
       { inherit llvm-or1k; });
    cargo = callPackage ./pkgs/rust/cargo.nix { inherit rustc; };
    cargo-vendor = callPackage ./pkgs/rust/cargo-vendor.nix {};
    llvmlite-artiq = callPackage ./pkgs/llvmlite-artiq.nix { inherit llvm-or1k; };
    libartiq-support = callPackage ./pkgs/libartiq-support.nix { inherit rustc; };
    artiq = callPackage ./pkgs/artiq.nix { inherit binutils-or1k llvm-or1k llvmlite-artiq libartiq-support lit outputcheck; };
    artiq-env = (pkgs.python3.withPackages(ps: [ artiq ])).overrideAttrs (oldAttrs: { name = "${pkgs.python3.name}-artiq-env-${artiq.version}"; });
    openocd = callPackage ./pkgs/openocd.nix {};

    conda-pythonparser = import ./conda/build.nix { inherit pkgs; } {
      name = "conda-pythonparser";
      src = import ./conda/fake-source.nix { inherit pkgs; } {
        name = "pythonparser";
        inherit (pythonDeps.pythonparser) version src;
        extraSrcCommands = "patch -p1 < ${./pkgs/python37hack.patch}";
        dependencies = ["regex"];
      };
    };
    conda-binutils-or1k = import ./conda/binutils.nix {
      inherit pkgs;
      inherit (binutils-or1k) version src;
      target = "or1k-linux";
    };
    conda-binutils-arm = import ./conda/binutils.nix {
      inherit pkgs;
      inherit (binutils-arm) version src;
      target = "armv7-unknown-linux-gnueabihf";
    };
    conda-llvm-or1k = import ./conda/llvm-or1k.nix {
      inherit pkgs;
      inherit (llvm-or1k) version;
      src = llvm-or1k.llvm-src;
    };
    conda-llvmlite-artiq = import ./conda/llvmlite-artiq.nix {
      inherit pkgs conda-llvm-or1k;
      inherit (llvmlite-artiq) version src;
    };
    conda-sipyco = import ./conda/build.nix { inherit pkgs; } {
      name = "conda-sipyco";
      src = import ./conda/fake-source.nix { inherit pkgs; } {
        name = "sipyco";
        inherit (pythonDeps.sipyco) version src;
        dependencies = ["numpy"];
      };
    };
    conda-quamash = import ./conda/build.nix { inherit pkgs; } {
      name = "conda-quamash";
      src = import ./conda/fake-source.nix { inherit pkgs; } {
        name = "quamash";
        inherit (pkgs.python3Packages.quamash) version src;
      };
    };
    conda-bscan-spi-bitstreams = import ./conda/bscan-spi-bitstreams.nix {
      inherit pkgs;
      inherit (openocd) bscan_spi_bitstreams;
    };
    conda-artiq = import ./conda/artiq.nix { inherit pkgs; };
    conda-asyncserial = import ./conda/build.nix { inherit pkgs; } {
      name = "conda-asyncserial";
      src = import ./conda/fake-source.nix { inherit pkgs; } {
        name = "asyncserial";
        inherit (pythonDeps.asyncserial) version src;
        dependencies = ["pyserial"];
      };
    };
  };

  condaWindows = {
    conda-windows-binutils-or1k = import ./conda-windows/redistribute.nix {
      inherit pkgs;
      name = "binutils-or1k";
      filename = "binutils-or1k-linux-2.27-h93a10e1_6.tar.bz2";
      baseurl = "https://anaconda.org/m-labs/binutils-or1k-linux/2.27/download/win-64/";
      sha256 = "0gbks36hfsx3893mihj0bdmg5vwccrq5fw8xp9b9xb8p5pr8qhzx";
    };
    conda-windows-llvm-or1k = import ./conda-windows/redistribute.nix {
      inherit pkgs;
      name = "llvm-or1k";
      filename = "llvm-or1k-6.0.0-25.tar.bz2";
      baseurl = "https://anaconda.org/m-labs/llvm-or1k/6.0.0/download/win-64/";
      sha256 = "06mnrg79rn9ni0d5z0x3jzb300nhqhbc2h9qbq5m50x3sgm8km63";
    };
    conda-windows-llvmlite-artiq = import ./conda-windows/redistribute.nix {
      inherit pkgs;
      name = "llvmlite-artiq";
      filename = "llvmlite-artiq-0.23.0.dev-py35_5.tar.bz2";
      baseurl = "https://anaconda.org/m-labs/llvmlite-artiq/0.23.0.dev/download/win-64/";
      sha256 = "10w24w5ljvan06pbvwqj4pzal072jnyynmwm42dn06pq88ryz9wj";
    };
  };
in
  mainPackages // condaWindows // boardPackages
