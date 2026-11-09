{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libxkbcommon,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  nspr,
  nss,
  pango,
  systemd,
  vulkan-loader,
  wayland,
}:
let
  version = "0.1.29894161";
  debs = {
    x86_64-linux = {
      arch = "amd64";
      hash = "sha256-mfMEkkgHqHJGUt33vkbSNuGDcedX4VW9qLN+w5IBz3U=";
    };
    aarch64-linux = {
      arch = "arm64";
      hash = "sha256-/73qCxsM60MXLSdQyhjdO2B6oCibXGpFZzAEWY+4f9A=";
    };
  };
  deb =
    debs.${stdenv.hostPlatform.system}
      or (throw "amp-desktop: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "amp-desktop";
  inherit version;

  src = fetchurl {
    url = "https://static.ampcode.com/linux/${version}/amp-desktop-${version}-${deb.arch}.deb";
    inherit (deb) hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    alsa-lib
    at-spi2-atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libxkbcommon
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    nspr
    nss
    pango
  ];

  unpackPhase = "dpkg-deb -x $src .";
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share
    cp -a opt/amp $out/opt/amp
    rm -f $out/opt/amp/chrome-sandbox
    cp -a usr/share/icons $out/share/icons
    install -Dm644 usr/share/applications/*.desktop $out/share/applications/amp-desktop.desktop
    substituteInPlace $out/share/applications/amp-desktop.desktop \
      --replace-fail /opt/amp/amp-desktop $out/bin/amp-desktop

    runHook postInstall
  '';

  preFixup = ''
    makeWrapper $out/opt/amp/amp-desktop $out/bin/amp-desktop \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libglvnd
          systemd
          vulkan-loader
          wayland
        ]
      } \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
  '';

  meta = {
    description = "Amp desktop app";
    homepage = "https://ampcode.com";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames debs;
    hydraPlatforms = [ ];
    mainProgram = "amp-desktop";
  };
}
