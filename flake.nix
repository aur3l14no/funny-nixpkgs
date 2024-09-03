{
  description = "Little tweaked funny nixpkgs, but for what?";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs?rev=23bcbb6dfd7ba49ef8d9326f4784f5d83545503e";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs =
    { self
    , nixpkgs
    , flake-utils
    ,
    }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };

      packageNames =
        builtins.filter (s: builtins.isString s && s != "") (builtins.split "\n" (builtins.readFile ./packages.txt)
          ++ builtins.attrNames (builtins.fromJSON (builtins.readFile ./nixpkgs_c_gt_0.json)));

      packageNamesLite = lib.take 10 packageNames;

      makePkgWithOptions = pkgName: { optLevel ? null
                                    , genDebug ? false
                                    }:
        if ! pkgs ? ${pkgName}
        then throw "missing package ${pkgName}"
        else if ! pkgs.${pkgName} ? overrideAttrs
        then throw "package ${pkgName} does not have `overrideAttrs`"
        else if !builtins.elem optLevel [ null "g" "0" "1" "2" "3" ]
        then throw "optLevel invalid"
        else
          let
            optFlag = if optLevel == null then "" else "-O${optLevel}";
          in
          pkgs.${pkgName}.overrideAttrs (oldAttrs: {
            doCheck = false;
            env.NIX_CFLAGS_COMPILE = (oldAttrs.env.NIX_CFLAGS_COMPILE or "") + " ${optFlag}";
          } // lib.optionalAttrs genDebug { separateDebugInfo = true; });

    in
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system: {
      packages =
        builtins.listToAttrs (builtins.filter (x: x != null) (lib.flatten (map
          (name:
            let
              packageSourcePair = if (builtins.tryEval (toString (pkgs.srcOnly pkgs.${name}))).success then lib.nameValuePair "${name}-src" (pkgs.srcOnly pkgs.${name}) else null;
              packageVariantPairs = map
                (optLevel:
                  if (builtins.tryEval (toString (makePkgWithOptions name { optLevel = optLevel; genDebug = true; }))).success
                  then lib.nameValuePair (if optLevel != null then "${name}-O${optLevel}" else name) (makePkgWithOptions name { optLevel = optLevel; genDebug = true; })
                  else null)
                [ null "0" "1" "2" "3" ];
            in
            [ packageSourcePair ] ++ packageVariantPairs)
          packageNames
        )));
      packagesLite =
        builtins.listToAttrs (builtins.filter (x: x != null) (lib.flatten (map
          (name:
            let
              packageSourcePair = if (builtins.tryEval (toString (pkgs.srcOnly pkgs.${name}))).success then lib.nameValuePair "${name}-src" (pkgs.srcOnly pkgs.${name}) else null;
              packageVariantPairs = map
                (optLevel:
                  if (builtins.tryEval (toString (makePkgWithOptions name { optLevel = optLevel; genDebug = true; }))).success
                  then lib.nameValuePair (if optLevel != null then "${name}-O${optLevel}" else name) (makePkgWithOptions name { optLevel = optLevel; genDebug = true; })
                  else null)
                [ null "0" "1" "2" "3" ];
            in
            [ packageSourcePair ] ++ packageVariantPairs)
          packageNamesLite
        )));
    })
  ;
}

