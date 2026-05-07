{
  description = "kubectl aliases — generated kubectl shell aliases";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      src = pkgs: pkgs.lib.fileset.toSource {
        root = ./.;
        fileset = pkgs.lib.fileset.unions [ ./generate_aliases.py ./license_header ];
      };

      mkAliasesFile = pkgs: shell:
        pkgs.runCommand "kubectl-aliases-${shell}" {
          nativeBuildInputs = [ pkgs.python3 ];
        } ''
          python3 ${src pkgs}/generate_aliases.py ${shell} > $out
        '';

      mkAliasesJson = pkgs:
        pkgs.runCommand "kubectl-aliases.json" {
          nativeBuildInputs = [ pkgs.python3 ];
        } ''
          python3 ${src pkgs}/generate_aliases.py zsh | python3 -c '
import sys, json, re
out = {}
for line in sys.stdin:
    m = re.match(r"alias ([^=]+)=\x27(.*)\x27$", line.rstrip())
    if m:
        out[m.group(1)] = m.group(2)
sys.stdout.write(json.dumps(out))
' > $out
        '';

      mkAliasAttrs = pkgs:
        builtins.fromJSON (builtins.readFile (mkAliasesJson pkgs));

      homeManagerModule = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.kubectl-aliases;
        in {
          options.programs.kubectl-aliases = {
            enable = lib.mkEnableOption "kubectl-aliases";

            zshIntegration.enable = lib.mkOption {
              type = lib.types.bool;
              default = cfg.enable;
              defaultText = lib.literalExpression "config.programs.kubectl-aliases.enable";
              description = ''
                Whether to add the generated kubectl aliases to
                {option}`programs.zsh.shellAliases`.
              '';
            };
          };

          config = lib.mkIf (cfg.enable && cfg.zshIntegration.enable) {
            programs.zsh.shellAliases = mkAliasAttrs pkgs;
          };
        };
    in
    {
      homeManagerModules.default = homeManagerModule;
      homeManagerModules.kubectl-aliases = homeManagerModule;

      lib = {
        inherit mkAliasAttrs mkAliasesFile mkAliasesJson;
      };
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        packages = {
          default = mkAliasesFile pkgs "zsh";
          bash = mkAliasesFile pkgs "bash";
          zsh = mkAliasesFile pkgs "zsh";
          fish = mkAliasesFile pkgs "fish";
          nushell = mkAliasesFile pkgs "nushell";
          json = mkAliasesJson pkgs;
        };
      });
}
