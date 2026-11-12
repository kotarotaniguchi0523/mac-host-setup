# mise from its official release binary, pinned by pkgs/mise-bin.json.
# The pin is written only by tools/ci/mise-bin-update.sh, after verifying the release's GitHub
# attestation and the GPG-signed SHASUMS256 (AUDIT.md). fetchurl re-checks the sha256 here.
# nixpkgs' source build lagged ~3 weeks behind upstream, so this replaces pkgs.mise.
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  pin = lib.importJSON ./mise-bin.json;
in
stdenvNoCC.mkDerivation {
  pname = "mise";
  inherit (pin) version;
  src = fetchurl { inherit (pin) url sha256; };
  sourceRoot = "mise";
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/mise "$out/bin/mise"
    [ -d man ] && mkdir -p "$out/share" && cp -r man "$out/share/"
    runHook postInstall
  '';
  meta = {
    description = "mise (official release binary, attestation + GPG verified)";
    homepage = "https://mise.jdx.dev";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "mise";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
