{ stdenv, lib, callPackage, fetchgit, git, python3Packages, qt5, binutils-or1k, binutils-arm, llvm-or1k, llvmlite-artiq, libartiq-support, lit, outputcheck }:

let
  pythonDeps = callPackage ./python-deps.nix {};
in
  python3Packages.buildPythonPackage rec {
    name = "artiq-${version}";
    version = import ./artiq-version.nix { inherit stdenv fetchgit git; };
    src = import ./artiq-src.nix { inherit fetchgit; };

    preBuild = "export VERSIONEER_OVERRIDE=${version}";

    nativeBuildInputs = [ qt5.wrapQtAppsHook ];
    propagatedBuildInputs = [ binutils-or1k llvm-or1k llvmlite-artiq ]
      ++ (lib.lists.optionals (lib.strings.versionAtLeast version "6.0") [ binutils-arm ])
      ++ (with pythonDeps; [ sipyco pyqtgraph-qt5 pythonparser ])
      ++ (with python3Packages; [ pygit2 numpy dateutil quamash scipy prettytable pyserial python-Levenshtein h5py pyqt5 ]);

    dontWrapQtApps = true;
    postFixup = ''
      wrapQtApp "$out/bin/artiq_dashboard"
      wrapQtApp "$out/bin/artiq_browser"
    '';

    checkInputs = [ binutils-or1k outputcheck ];
    checkPhase =
    ''
    python -m unittest discover -v artiq.test

    TESTDIR=`mktemp -d`
    cp --no-preserve=mode,ownership -R ${src}/artiq/test/lit $TESTDIR
    LIBARTIQ_SUPPORT=${libartiq-support}/libartiq_support.so ${lit}/bin/lit -v $TESTDIR/lit
    '';


    meta = with stdenv.lib; {
      description = "A leading-edge control system for quantum information experiments";
      homepage = https://m-labs/artiq;
      license = licenses.lgpl3;
      maintainers = [ maintainers.sb0 ];
    };
  }
