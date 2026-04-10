{
  lib,
  stdenv,
  fetchFromGitHub,
  nodejs_20,
  pnpm_9,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
}:

let
  pnpm = pnpm_9;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "langfuse";
  version = "2.95.1";

  src = fetchFromGitHub {
    owner = "langfuse";
    repo = "langfuse";
    rev = "v${finalAttrs.version}";
    hash = "sha256-KpeZMipnYTeVMCdU1YEJRMIXjIylRYWdZrSCDkCrhdM=";
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    # To compute: NIX_NPM_REGISTRY=https://registry.npmjs.org nix build .#langfuse.pnpmDeps
    # Then replace with the hash from the error message.
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    fetcherVersion = 1;
  };

  nativeBuildInputs = [
    nodejs_20
    pnpm_9
    pnpmConfigHook
    makeWrapper
  ];

  env = {
    DOCKER_BUILD = "1";
    NEXT_TELEMETRY_DISABLED = "1";
    NEXT_MANUAL_SIG_HANDLE = "true";
    CI = "true";
  };

  buildPhase = ''
    runHook preBuild

    # Self-hosted builds remove the cloud middleware (matches upstream Dockerfile)
    rm -f ./web/src/middleware.ts

    pnpm --filter=web... run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/langfuse

    # Next.js standalone server output
    cp -r web/.next/standalone/. $out/lib/langfuse/
    cp -r web/.next/static $out/lib/langfuse/web/.next/static
    cp -r web/public $out/lib/langfuse/web/public

    # Prisma schema + migration files (used by ExecStartPre in the NixOS module)
    mkdir -p $out/lib/langfuse/packages/shared
    cp -r packages/shared/prisma $out/lib/langfuse/packages/shared/prisma
    cp -r packages/shared/scripts $out/lib/langfuse/packages/shared/scripts

    # Prisma CLI from the pnpm workspace (version-matched to the schema)
    cp -rL node_modules/prisma $out/lib/langfuse/prisma-cli

    # Server wrapper
    makeWrapper ${nodejs_20}/bin/node $out/bin/langfuse-server \
      --add-flags "$out/lib/langfuse/web/server.js" \
      --add-flags "--keepAliveTimeout" \
      --add-flags "110000"

    # Migration wrapper (runs prisma migrate deploy)
    makeWrapper ${nodejs_20}/bin/node $out/bin/langfuse-migrate \
      --add-flags "$out/lib/langfuse/prisma-cli/build/index.js" \
      --add-flags "migrate" \
      --add-flags "deploy" \
      --add-flags "--schema=$out/lib/langfuse/packages/shared/prisma/schema.prisma"

    # Cleanup SQL wrapper (runs prisma db execute)
    makeWrapper ${nodejs_20}/bin/node $out/bin/langfuse-db-cleanup \
      --add-flags "$out/lib/langfuse/prisma-cli/build/index.js" \
      --add-flags "db" \
      --add-flags "execute" \
      --add-flags "--file=$out/lib/langfuse/packages/shared/scripts/cleanup.sql"

    runHook postInstall
  '';

  meta = {
    description = "Open-source LLM observability, tracing, and evaluation platform";
    homepage = "https://langfuse.com";
    license = lib.licenses.mit;
    maintainers = [ ];
    mainProgram = "langfuse-server";
    platforms = lib.platforms.linux;
  };
})
