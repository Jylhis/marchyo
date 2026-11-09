{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "marchyo-agent-skills";
  version = "1";
  src = ./skills;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/marchyo/skills"
    cp -r . "$out/share/marchyo/skills/"
    install -Dm0644 ${./PROVENANCE} "$out/share/doc/marchyo-agent-skills/PROVENANCE"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    for skill in "$out"/share/marchyo/skills/*/; do
      name=$(basename "$skill")
      grep -q "^name: $name\$" "$skill/SKILL.md" \
        || { echo "$name: SKILL.md name does not match its directory" >&2; exit 1; }
      grep -q '^description:' "$skill/SKILL.md" \
        || { echo "$name: SKILL.md has no description" >&2; exit 1; }
    done
  '';

  passthru.skillNames = [
    "marchyo"
    "marchyo-plugin"
    "diagnose-crash"
  ];

  meta = {
    description = "Agent skills for working on a Marchyo system";
    homepage = "https://github.com/jylhis/marchyo";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
