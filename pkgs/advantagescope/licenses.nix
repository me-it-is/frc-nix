{ buildNpmPackage
, src
, pname
, version
, nodejs
, npmDepsHash
, cacert
, patches
, system
, ...
}:
let
  finalHash = {
    "x86_64-linux" = "sha256-ygt3JJfDkxiKbMFax19nR6r1oBsvV9DxBno3AE3O0B4=";
    "aarch64-linux" = "sha256-ygt3JJfDkxiKbMFax19nR6r1oBsvV9DxBno3AE3O0B4=";
    "x86_64-darwin" = "sha256-clGPBAsyN+dbBWZ0YoW0TAc7GNMrNnyxF+a9kgWGDsE=";
    "aarch64-darwin" = "sha256-clGPBAsyN+dbBWZ0YoW0TAc7GNMrNnyxF+a9kgWGDsE=";
  }."${system}" or (throw "Unsupported system: ${system}");
in
buildNpmPackage (finalAttrs: {
  pname = pname + "-licenses";
  inherit version src npmDepsHash patches;

  makeCacheWritable = true;
  npmFlags = [ "--ignore-scripts" ];

  buildPhase = ''
    export NODE_EXTRA_CA_CERTS="${cacert}/etc/ssl/certs/ca-bundle.crt"
    node getLicenses.mjs
  '';

  installPhase = ''
    mkdir out
    mv ./src/licenses.json ./out
    cp -r ./out $out
  '';

  outputHashAlgo = "sha256";
  outputHashMode = "recursive";
  outputHash = finalHash;

  buildInputs = [ nodejs ];
})
