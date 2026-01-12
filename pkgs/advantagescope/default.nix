{ lib
, buildNpmPackage
, fetchFromGitHub
, emscripten
, electron
, libGL
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, callPackage
, isWPILibVersion ? false
, stdenv
}:
let
  pname = "advantage-scope";
  version = "26.0.0";

  src = fetchFromGitHub {
    owner = "Mechanical-Advantage";
    repo = "AdvantageScope";
    tag = "v${version}";
    hash = "sha256-ZkA7u/QlM5+w4l6ZrlRAxhtPelyLi4LqSjGs27IFGKU=";
  };

  patches = [
    ./0001-change-build-targets.patch
    ./0001-fix-wasm-compile.patch
    ./0001-switch-youtube-dl-to-patch-with-package-lock.json.patch
  ];

  fetchersAtters = {
    inherit
      version
      npmDepsHash
      src
      pname
      patches
      system
      ;
  };

  docs = callPackage ./docs.nix fetchersAtters;
  licenses = callPackage ./licenses.nix fetchersAtters;
  tesseract = callPackage ./tesseract-lang.nix fetchersAtters;
  npmDepsHash = "sha256-SfgTiK4Bs5u1rxzytMeMue8xqn34fagYt2qzrhEkWfs=";

  system = stdenv.hostPlatform.system;

  finalOutDir = 
  {
    "x86_64-linux" = "linux-unpacked";
    "aarch64-linux" = "linux-arm64-unpacked";
    "x86_64-darwin" = "macos";
    "aarch64-darwin" = "macos-arm64";
  }."${system}" or (throw "Unsupported system: ${system}");
in
buildNpmPackage (finalAttrs: {
  inherit
    version
    npmDepsHash
    src
    pname
    patches
    ;

  makeCacheWritable = true;
  npmFlags = [
    "--legacy-peer-deps"
    "--ignore-scripts"
  ];

  # disable code signing on macos
  # https://github.com/electron-userland/electron-builder/blob/77f977435c99247d5db395895618b150f5006e8f/docs/code-signing.md#how-to-disable-code-signing-during-the-build-process-on-macos
  postConfigure = lib.optionalString stdenv.hostPlatform.isDarwin ''
    export CSC_IDENTITY_AUTO_DISCOVERY=false
  '';

  preBuild = ''
    cd $TMPDIR
    export EMSCRIPTENCACHE=$(mkdir emscriptencache)
    cd $./source
    '' + lib.optionalString stdenv.hostPlatform.isDarwin ''
      cp -r ${electron.dist}/Electron.app .
      chmod -R u+w Electron.app
    ''
    + lib.optionalString stdenv.hostPlatform.isLinux ''
      cp -r ${electron.dist} electron-dist
      chmod -R u+w electron-dist
    '';

  buildPhase = ''
    export ASCOPE_DISTRIBUTION=${lib.optionalString isWPILibVersion "WPILIB"}
    cp ${licenses}/licenses.json ./src/
    npm run compile
    npm run wasm:compile
    cp -r ${docs} ./docs/build/
    cp ${tesseract}/eng.traineddata.gz ./
    npx electron-builder build -l -c.electronDist=${if stdenv.hostPlatform.isDarwin then "." else "electron-dist"} -c.electronVersion=${electron.version}
  '';

  installPhase = lib.optionalString stdenv.hostPlatform.isLinux ''
    mkdir -p $out/bin
    ls ./dist
    cp -r ./dist/${finalOutDir}/. $out/bin/
    install -Dm444 "${src}"/icons/app/app-icons-linux/icon_512x512.png "$out"/share/pixmaps/${pname}.png
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    mkdir -p $out/{Applications,bin}
    mv dist/{finalOutDir}/AdvantageScope.app $out/Applications/AdvantageScope.app
  ''
  + ''
    runHook postInstall
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/advantagescope \
    --set LD_LIBRARY_PATH ${
      lib.makeLibraryPath [
        libGL
      ]
    } \
    --append-flags "--no-sandbox"
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    wrapProgram $out/Applications/AdvantageScope.app/Contents/MacOS/AdvantageScope \
    --set LD_LIBRARY_PATH ${
      lib.makeLibraryPath [
        libGL
      ]
    } \
    --append-flags "--no-sandbox"
  '';

  desktopItems = [
    lib.optional stdenv.hostPlatform.isLinux (makeDesktopItem {
      desktopName = "AdvantageScope";
      name = pname;
      exec = "advantagescope";
      icon = pname;
      categories = [
        "Robotics"
        "Development"
      ];
      keywords = [
        "FRC"
        "Data"
        "Visualisation"
      ];
    })
  ];

  meta = {
    description = "AdvantageScope is a robot diagnostics, log review/analysis, and data visualization application for FIRST teams developed by Team 6328";
    homepage = "https://docs.advantagescope.org/";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ me-it-is ];
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };

  nativeBuildInputs = [
    emscripten
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [ makeWrapper ];
})
