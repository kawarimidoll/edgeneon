{
  stdenv,
  swift,
  # Git-derived by the flake (see flake.nix). Defaults to "dev" for a bare
  # `nix-build`/`callPackage` outside the flake.
  version ? "dev",
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "edgeneon";
  inherit version;
  src = ./.;

  nativeBuildInputs = [ swift ];

  buildPhase = ''
    runHook preBuild
    # Inject the resolved version into main.swift, replacing the "dev"
    # placeholder it carries so a standalone `swiftc` build still compiles.
    substituteInPlace main.swift \
      --replace-fail 'let edgeneonVersion = "dev"' 'let edgeneonVersion = "${finalAttrs.version}"'
    swiftc -O main.swift -o edgeneon
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 edgeneon $out/bin/edgeneon
    runHook postInstall
  '';

  meta = {
    description = "Neon light on the display edge";
    homepage = "https://github.com/kawarimidoll/edgeneon";
    license = "MIT";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    mainProgram = "edgeneon";
  };
})
