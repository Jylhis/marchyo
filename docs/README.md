# Marchyo Documentation

This directory contains the Marchyo documentation site built with mdBook and nix-mdbook.

## Building

### Build Documentation

```bash
nix build .#docs
```

The built documentation will be in `./result`.

### Serve Locally

```bash
nix run .#serve-docs
```

Then open http://localhost:8000 in your browser.

### Install Offline Documentation

```bash
nix build .#marchyo-docs
./result/bin/marchyo-docs
```

## Structure

```
docs/
├── book.toml              # mdBook configuration
├── src/                   # Documentation source
│   ├── SUMMARY.md        # Table of contents
│   ├── index.md          # Landing page
│   ├── tutorials/        # Learning-oriented guides
│   ├── how-to/           # Problem-solving guides
│   ├── reference/        # Technical reference
│   └── explanation/      # Conceptual documentation
├── theme/                # Custom CSS
├── default.nix           # Build configuration
└── generate-options.nix  # Auto-generate module options

```

## Auto-Generated Content

Module options are automatically generated from source code:

- **NixOS Options**: From `modules/nixos/`
- **Home Manager Options**: From `modules/home/`

These are regenerated on every build, ensuring documentation stays up-to-date.

## Documentation Structure (Diataxis)

We follow the [Diataxis](https://diataxis.fr/) framework:

- **Tutorials**: Learning-oriented, step-by-step guides
- **How-To Guides**: Problem-oriented, task-focused recipes
- **Reference**: Information-oriented, technical descriptions
- **Explanation**: Understanding-oriented, conceptual discussions

## Adding Content

### Add a New Tutorial

1. Create `src/tutorials/my-tutorial.md`
2. Add to `src/SUMMARY.md`:
   ```markdown
   - [My Tutorial](tutorials/my-tutorial.md)
   ```
3. Rebuild documentation

### Add Custom CSS

Edit `theme/css/custom.css` and rebuild.

## Deployment

Documentation is automatically built and deployed to GitHub Pages when changes are pushed to the `main` branch.

See `.github/workflows/docs.yml` for the CI/CD configuration.

## Development

### Quick Iteration

For fast feedback during writing:

1. Edit markdown files in `src/`
2. Rebuild: `nix build .#docs`
3. View: `nix run .#serve-docs`

### Check Build Logs

```bash
nix build .#docs --print-build-logs
```

## Troubleshooting

### Build Fails

Check flake evaluation:
```bash
nix flake check
```

### Options Not Generated

Ensure modules are evaluating correctly:
```bash
nix eval .#nixosModules.default --show-trace
```

### mdBook Errors

Build with verbose output:
```bash
nix build .#docs --print-build-logs
```

## Resources

- [mdBook Documentation](https://rust-lang.github.io/mdBook/)
- [nix-mdbook](https://github.com/pbar1/nix-mdbook)
- [Diataxis Framework](https://diataxis.fr/)
- [Base16 Theming](https://github.com/chriskempson/base16)
