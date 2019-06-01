{ pkgs ? import <nixpkgs> {}, rustManifest ? ./stm32/channel-rust-nightly.toml }:

let
  jobs = pkgs.callPackage ./stm32/default.nix {
    inherit rustManifest;
    mozillaOverlay = import <mozillaOverlay>;
  };
in
  builtins.mapAttrs (key: value: pkgs.lib.hydraJob value) jobs
