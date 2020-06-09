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
    inherit (pythonDeps) sipyco asyncserial levenshtein pythonparser quamash pyqtgraph-qt5 misoc migen microscope jesd204b migen-axi lit outputcheck;
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
    conda-sipyco = import ./conda/build.nix { inherit pkgs; } {
      name = "conda-sipyco";
      src = import ./conda/fake-source.nix { inherit pkgs; } {
        name = "sipyco";
        inherit (pythonDeps.sipyco) version src;
      };
    };
    conda-bscan-spi-bitstreams = import ./conda/bscan-spi-bitstreams.nix {
      inherit pkgs;
      inherit (openocd) bscan_spi_bitstreams;
    };
    conda-artiq = import ./conda/artiq.nix { inherit pkgs; };
  };
in
  mainPackages // boardPackages
