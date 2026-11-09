# Adapted from olafkfreund/nixarchy pkgs/gliff/default.nix (MIT).
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  nasm,
  wrapGAppsHook4,
  gtk4,
  libadwaita,
  libva,
  libdrm,
  libgbm,
  wayland,
  libxkbcommon,
  dbus,
  vulkan-loader,
  openssh,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "gliff";
  version = "0.4.2";

  src = fetchFromGitHub {
    owner = "omacom";
    repo = "gliff";
    tag = "v${finalAttrs.version}";
    hash = "sha256-SUvnAxmXyBqPrtgBfEp06/KHlO0m2OtaP+lVaFgK04M=";
  };

  cargoHash = "sha256-cwa2ECXZ1LPJnJO1FwZF7ke+eZ40H/6nSTicRKW9+08=";

  nativeBuildInputs = [
    pkg-config
    nasm
    wrapGAppsHook4
  ];
  buildInputs = [
    gtk4
    libadwaita
    libva
    libdrm
    libgbm
    wayland
    libxkbcommon
    dbus
    vulkan-loader
  ];

  doCheck = true;
  dontWrapGApps = true;

  postInstall = ''
    install -Dm644 pkgbuild/gliff.desktop -t $out/share/applications
    install -Dm644 pkgbuild/gliff.svg -t $out/share/icons/hicolor/scalable/apps
  '';

  # ash dlopens libvulkan.so.1 by name; without the RUNPATH entry gliff falls back to the CPU tier.
  postFixup = ''
    for b in gliff gliff-server gliff-probe; do
      patchelf --add-rpath ${lib.makeLibraryPath [ vulkan-loader ]} $out/bin/$b
    done
    wrapGApp $out/bin/gliff --prefix PATH : ${lib.makeBinPath [ openssh ]}
  '';

  meta = {
    description = "Remote desktop over SSH for Wayland";
    homepage = "https://github.com/omacom/gliff";
    license = with lib.licenses; [
      mit
      bsd2
    ];
    mainProgram = "gliff";
    platforms = [ "x86_64-linux" ];
  };
})
