# TODO: Remaining Flake-Parts Module Tasks

## Overview
The core flake-parts module implementation is complete and committed (commit d45996a). The following tasks remain to fully complete the enhancement initiative.

## Completed ✅

- [x] Design flake module architecture and plan implementation
- [x] Implement modular flake-parts structure (options.nix, systems.nix, helpers.nix, lib.nix)
- [x] Create perSystem helpers (builders, packages, colorSchemes, devShell, apps)
- [x] Add comprehensive helper documentation (docs/HELPERS.md)
- [x] Create usage example (examples/flake-module-usage.nix)
- [x] Update template with helper usage examples
- [x] Test implementation (nix flake check passes)
- [x] Commit working changes

## Remaining Tasks 🔨

### 1. Implement Auto-Testing Infrastructure
**Priority:** Medium
**Effort:** 2-3 hours

Create automated test generation for nixosConfigurations defined via `flake.marchyo.systems`.

**Files to create/modify:**
- `modules/flake/testing.nix` - Auto-test generation logic
- Update `modules/flake/options.nix` - Add `marchyo.testing.enable` option
- Update `modules/flake/default.nix` - Import testing module

**Features:**
- Option to auto-generate VM tests for each defined system
- Validate that systems build successfully
- Basic smoke tests (system boots, hostname is correct, etc.)
- Integration with existing tests/ directory
- Conditional based on `marchyo.testing.enable` flag

**Example:**
```nix
flake.marchyo = {
  testing.enable = true;
  systems.workstation.modules = [ ./config.nix ];
};
# Auto-generates: checks.x86_64-linux.workstation-test
```

---

### 2. Update Workstation Template with Declarative API
**Priority:** High
**Effort:** 30 minutes

Update `templates/workstation/flake.nix` to demonstrate the new declarative system configuration API, not just helpers.

**Current state:** Template shows helper usage but still uses old `withSystem` + `mkNixosSystem` pattern
**Goal:** Show the simplified declarative approach

**Changes needed in templates/workstation/flake.nix:**
```nix
# Replace this:
nixosConfigurations.workstation = withSystem "x86_64-linux" ({ inputs', ... }:
  inputs.marchyo.lib.marchyo.mkNixosSystem {
    system = "x86_64-linux";
    modules = [ ./configuration.nix ];
    extraSpecialArgs = { inherit inputs'; };
  }
);

# With this:
flake.marchyo.systems.workstation = {
  modules = [ ./configuration.nix ];
  # system = "x86_64-linux" is automatic
};
```

**Optional:** Keep old approach commented out with "Legacy approach (still supported)" note

---

### 3. Create modules/flake/README.md
**Priority:** High
**Effort:** 1 hour

Comprehensive documentation for the flake module itself.

**Sections to include:**
- Overview and purpose
- Quick start guide
- Option reference (`flake.marchyo.systems`, `flake.marchyo.helpers`)
- Architecture explanation (how it works under the hood)
- Migration guide from old `mkNixosSystem` approach
- Advanced usage examples
- Troubleshooting common issues
- Integration with existing marchyo features

**Location:** `/home/markus/Developer/marchyo/modules/flake/README.md`

**Reference:** Use docs/HELPERS.md as inspiration for structure and detail level

---

### 4. Update CLAUDE.md with Flake Module Capabilities
**Priority:** High
**Effort:** 20 minutes

Add section documenting the new flake-parts module capabilities.

**File:** `/home/markus/Developer/marchyo/CLAUDE.md`

**Add new section:**
```markdown
### Flake Module (for flake-parts users)

Marchyo provides a comprehensive flake-parts module that simplifies NixOS configuration.

**Declarative System Configuration:**
```nix
flake.marchyo.systems.hostname = {
  system = "x86_64-linux";  # optional, defaults to x86_64-linux
  modules = [ ./configuration.nix ];
  extraSpecialArgs = { };  # optional
};
```

**Available Helpers in perSystem:**
- `marchyo.packages` - Custom packages (plymouth-marchyo-theme, hyprmon)
- `marchyo.builders` - VM, ISO, and system builders
- `marchyo.colorSchemes` - Access to all color schemes
- `marchyo.devShells.default` - Pre-configured development environment
- `marchyo.apps` - Utility applications

See modules/flake/README.md and docs/HELPERS.md for comprehensive documentation.
```

---

### 5. Update README.md with Flake-Parts Usage Examples
**Priority:** High
**Effort:** 30 minutes

Add prominent section showing the new flake-parts workflow.

**File:** `/home/markus/Developer/marchyo/README.md`

**Add section after "Usage":**
```markdown
## Usage with flake-parts

For users leveraging flake-parts, marchyo provides a streamlined module:

```nix
{
  inputs.marchyo.url = "github:your-org/marchyo";

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [ inputs.marchyo.flakeModules.default ];

      flake.marchyo.systems = {
        myhost = {
          modules = [
            ./hardware-configuration.nix
            { marchyo.desktop.enable = true; }
          ];
        };
      };

      # Optional: Use helpers in perSystem
      perSystem = { marchyo, ... }: {
        packages.vm = marchyo.builders.vm "myhost";
        devShells.default = marchyo.devShells.default;
      };
    };
}
```

See [templates/workstation](./templates/workstation) for a complete example.
```

**Also update:**
- Table of contents (add "Usage with flake-parts")
- Link to modules/flake/README.md
- Link to docs/HELPERS.md

---

## Nice-to-Have Enhancements (Future)

These are lower priority but would add value:

### 6. Add More perSystem Helpers
- `marchyo.packages.hyprland-config-gen` - Generate Hyprland configs
- `marchyo.themes.apply` - Helper to apply themes to configs
- `marchyo.profiles.*` - Pre-configured system profiles

### 7. Create Nix Flake Templates
Add template variants:
- `templates.minimal` - Minimal marchyo setup
- `templates.server` - Headless server configuration
- `templates.flake-parts` - Clean flake-parts example (separate from workstation)

### 8. Add Validation and Linting
- `marchyo.apps.lint` - Lint marchyo configurations
- `marchyo.apps.validate` - Validate system definitions
- Better error messages for common mistakes

### 9. Integration Tests for Flake Module
Create tests specifically for the flake module:
- Test that declarative systems generate correctly
- Test helper functions work as expected
- Test error handling

---

## Notes

- All core functionality is implemented and tested (nix flake check passes)
- The module is backward compatible (old mkNixosSystem still works)
- Documentation exists in docs/HELPERS.md but needs to be surfaced in main docs
- Template shows helper usage but not declarative system configuration

## Effort Estimate

Total remaining work: **~5-6 hours**

- Auto-testing infrastructure: 2-3 hours
- Documentation updates (README, CLAUDE.md, modules/flake/README.md): 2 hours
- Template update: 30 minutes
- Review and polish: 30 minutes

## Priority Order

1. **Update template with declarative API** (high impact, low effort)
2. **Update README.md** (high visibility)
3. **Update CLAUDE.md** (important for AI assistance)
4. **Create modules/flake/README.md** (comprehensive reference)
5. **Auto-testing infrastructure** (nice feature, but lower priority)

---

Generated: 2025-10-19
Status: Core implementation complete, documentation pending
