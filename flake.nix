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

      # VERSION holds the CalVer of the last release, which is also its tag, so
      # `--version` names the release it came from. The short hash is always
      # appended: a flake can see its own revision but not the tag it was
      # fetched by, so this is what distinguishes the tagged build from any
      # later commit that still reads the same VERSION.
      version =
        let
          released = nixpkgs.lib.fileContents ./VERSION;
          rev = self.shortRev or self.dirtyShortRev or "dirty";
        in
        "${released}-${rev}";
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
