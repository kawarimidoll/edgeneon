{
  description = "Neon light on the display edge";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      # macOS only — edgeneon draws AppKit windows under the menu bar.
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Version is derived from git, not stored in-tree: CalVer date of the
      # source commit plus its short hash (e.g. 2026.07.28-a1b2c3d). So `main`
      # always reports the build it actually is, and `nix flake update` picks up
      # both the new code and a fresh version with no in-repo bump.
      version =
        let
          d = self.lastModifiedDate; # "YYYYMMDDHHMMSS"
          date = "${builtins.substring 0 4 d}.${builtins.substring 4 2 d}.${builtins.substring 6 2 d}";
          rev = self.shortRev or self.dirtyShortRev or "dirty";
        in
        "${date}-${rev}";
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.callPackage ./package.nix { inherit version; };
        }
      );
    };
}
