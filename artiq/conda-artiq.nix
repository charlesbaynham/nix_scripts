{ pkgs }:

let
  version = import ./pkgs/artiq-version.nix;
  fakeCondaSource = import ./conda-fake-source.nix { inherit pkgs; } {
    name = "artiq";
    inherit version;
    src = import ./pkgs/artiq-src.nix { fetchgit = pkgs.fetchgit; };
    dependencies = import ./conda-artiq-deps.nix;
  };
  conda-artiq = import ./conda-build.nix { inherit pkgs; } {
    name = "conda-artiq";
    src = fakeCondaSource;
  };
in
  conda-artiq
