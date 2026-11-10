# Marchyo Tests

Evaluation tests that run during `nix flake check`, plus build checks that run
on demand (`just check-full`) and weekly in CI.

## Running Tests

```bash
just check          # nix flake check --no-build (evaluates every check) + statix + deadnix
nix flake check     # also builds the cheap checks (trivial text files, node suites)
just check-full     # nix flake check, then builds every heavy check

# List the checks
nix eval .#checks.x86_64-linux --apply builtins.attrNames

# Run one check
nix build .#checks.x86_64-linux.ref-desktop

# List / build the heavy checks
nix eval .#legacyPackages.x86_64-linux.heavyChecks --apply builtins.attrNames
nix build .#legacyPackages.x86_64-linux.heavyChecks.check-home-hyprland-config-shell
```

## How the suite is organised

A full `lib.nixosSystem` evaluation of the marchyo modules with a Home Manager
user costs seconds. The suite therefore evaluates a small set of **reference
systems** once each and runs many tests against each of them:

- **Reference systems** (`refBases` in `lib.nix`): `minimal` (no user),
  `headless`, `headless-dev`, `desktop`, `desktop-shell-off`,
  `desktop-dictation`, `full` (every feature flag), the graphics layouts
  (`nvidia`, `prime-offload`, `desktop-amd`) and the **tweak systems**
  (`headless-tweaks*`, `dev-tweaks`, `minimal-tweaks`, `desktop-tweaks*`,
  `desktop-light`, `desktop-off`, `shell-off-tweaks`, `nvidia-tweaks`,
  `amd-tweaks`). The pinned ones (`pinnedRefs`) are the marchyo defaults for
  one kind of host. The tweak systems collect non-default settings from many
  test files, each from the file that tests it (`refConfig`).
- **Tests are predicates.** A test is a named function from the evaluated
  `config` to `true` (pass), `false`, a failure message, or a list of failure
  messages (`[ ]` passes). Each reference system becomes one check,
  `ref-<name>`, that forces the system's assertions, runs every predicate on
  it, and on failure lists every failing predicate by name:

  ```
  error: FAIL: ref-desktop: 1 of 120 predicate(s) failed:
    - eval-greeter-default: returned false
  ```

  A predicate that needs the system's own package set is written
  `{ config, pkgs, ... }: …` instead. A predicate that throws is reported as such; read its error with
  `nix eval .#legacyPackages.x86_64-linux.testPredicates.<check>.<predicate>`.
  A predicate sees only its own system. To check the other side of a setting,
  add a second predicate on the other system rather than comparing the two;
  `helpers.ref "<name>"` evaluates another reference system when a comparison
  is unavoidable (two builds that must differ), at the cost of one more
  evaluation. Each check builds its own system, so it is garbage once the
  check is evaluated and `nix flake check` never holds every system in
  memory at once.
- **Variants** are configurations no other test shares (a distinct multi-GPU
  topology, a setting that changes the whole system); each is one check,
  `variant-<name>`.
- **Negative tests** (an assertion must fail) all run in one check,
  `eval-assertions`, which forces only `config.assertions`. Independent
  misconfigurations share the failing systems `misconfigured`,
  `misconfigured-2`, `misconfigured-3` and the Home-Manager-free
  `misconfigured-minimal*` (`failingBases` in `lib.nix`); each
  case names the assertion text it expects, so cases cannot satisfy each other.
- **Option-level tests** that need no system at all (types, enums, defaults
  derived from other marchyo options) use `helpers.evalOptions`, a
  `lib.evalModules` over `modules/nixos/options/` that takes a fraction of a
  second.
- **Heavy checks** build something (Hyprland `--verify-config` runs, theme
  asset dirs, the Plymouth theme, the shell wrapper, the installer ISO
  evaluations). They live in `legacyPackages.<system>.heavyChecks`, outside
  the default `checks`, and run with `just check-full` and the weekly
  `Heavy checks` CI job.

Every merge (files into checks, predicates into a reference system, check sets
in `outputs.nix`) throws on a duplicate name instead of silently shadowing it
(`lib/merge-unique.nix`).

## Test Structure

- `default.nix` — Entry point. Auto-discovers every file in `eval/`, builds the
  reference and failing systems from their contributions, and turns predicates
  into checks.
- `lib.nix` — The harness (`mkSystem`, `evalOptions`, `predicateCheck`,
  `assertionCheck`), the reference and failing system bases, and shared helpers
  (`withTestUser`, `desktopWith`, `minimalConfig`, `expect`, `throws`, the
  `hypr*` bind helpers, `assertTest`).
- `eval/` — One file per feature. Each is a function of `helpers`, `lib`,
  `pkgs` and the module sets, returning an attrset with any of:

  | Key | Value |
  | --- | --- |
  | `refs.<ref>.<test>` | predicate run on reference system `<ref>` |
  | `refConfig.<ref>` | module merged into tweak system `<ref>` |
  | `variants.<v>` | `{ config = <module>; predicates = { … }; }` |
  | `failing.<test>` | `{ on = "misconfigured"; expect = "…"; }` (or `system`/`config` instead of `on`); `expect` may be a list, all in one message |
  | `failingConfig.<sys>` | module merged into failing system `<sys>` |
  | `checks.<test>` | any other cheap check (a derivation), e.g. `assertTest` |
  | `heavy.<test>` | a build check (goes to `heavyChecks`) |

- `lib-tests.nix` — Unit tests for lib functions (`assertTest`).
- `shell/`, `cli/` — Node and shell suites, wired as checks in `outputs.nix`.

## Adding Tests

Add a predicate to the reference system that already has the configuration
you need. For a default behaviour that is a pinned system:

```nix
# tests/eval/my-feature.nix
{ lib, ... }:
{
  refs.desktop.eval-my-feature-default = cfg: cfg.services.my-feature.enable;
  refs.headless.eval-my-feature-headless-off = cfg: !cfg.services.my-feature.enable;
}
```

For a non-default setting, put it on a tweak system with `refConfig` and test
it there:

```nix
{ helpers, lib, ... }:
{
  refs.desktop-tweaks.eval-my-feature-port =
    cfg:
    helpers.expect (lib.elem 1234 cfg.networking.firewall.allowedTCPPorts) "port 1234 is not open";

  refConfig.desktop-tweaks.marchyo.myFeature.port = 1234;
}
```

A tweak only belongs on a tweak system if every other predicate there still
holds; `nix flake check` tells you when one does not. If your setting conflicts
with what a tweak system already carries, use another one (or add a numbered
one to `refBases`). Only when a test needs a configuration that genuinely
cannot share (it changes the whole system, or compares two builds that must
differ in one setting alone) make it a variant.

For a negative test, add the misconfiguration to a failing system and name the
assertion text:

```nix
{
  failing.eval-my-feature-needs-port = {
    on = "misconfigured";
    expect = "marchyo.myFeature.port must be set";
  };
  failingConfig.misconfigured.marchyo.myFeature.enable = true;
}
```

Files are auto-discovered; no edit to `default.nix` is needed.

### Library Test

Add to `lib-tests.nix`:

```nix
test-my-function = assertTest "my-function" (
  myFunction "input" == "expected"
) "Expected myFunction to return 'expected'";
```
