##
# This stub combines every other file into one cohesive set.
{ nixpkgs, ... }@inputs:
let
  inherit (nixpkgs.lib) fixedPoints mapAttrs mapAttrsToList;


  targets = {
    dag = ./dag.nix;
    eval = ./eval.nix;
    flakes = ./flakes.nix;
    futures = ./futures.nix;
    syntax = ./syntax.nix;
    derivation = ./derivation.nix;
  };

  imported = mapAttrs (_: v: import v) targets;
  asSegment = self: target: target (self // inputs // { lib = self; inherit inputs; });

  raw = fixedPoints.makeExtensible (self: 
    let
      raw = mapAttrs (_: v: (asSegment self v)) imported;
      concat = builtins.foldl' (a: b: a//b) {} (builtins.map (n: raw.${n}) (builtins.attrNames targets));
    in
    raw // { __finished__ = raw // concat; }
  );
in
  raw.__finished__
