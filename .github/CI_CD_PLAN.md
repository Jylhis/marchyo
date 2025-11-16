# CI/CD Enhancement Plan

## Current State

**Existing Workflows:**
1. `cachix-push.yml` - Check, build, and push to Cachix
2. `docs.yml` - Build and deploy documentation
3. `flakehub-publish-rolling.yml` - Publish to FlakeHub
4. `claude.yml` - Claude Code integration
5. `claude-code-review.yml` - Automated code reviews

## Enhancements to Implement

### 1. Comprehensive Build & Test Workflow

**File:** `.github/workflows/ci.yml`

**Features:**
- Run on every PR and push
- Parallel job matrix for different builds
- Run lightweight tests (`nix flake check`)
- Build system configurations
- Build packages
- Upload build artifacts
- Status checks for PRs

### 2. Release Automation

**File:** `.github/workflows/release.yml`

**Features:**
- Trigger on version tags (v*.*.*)
- Auto-generate changelog from commits
- Build installer ISOs (minimal + graphical)
- Create GitHub Release
- Upload ISO artifacts
- Update release notes

### 3. Dependency Updates

**File:** `.github/workflows/update-flake.yml`

**Features:**
- Weekly automated flake updates
- Create PR with updates
- Run tests on updated flake
- Auto-merge if tests pass (optional)

### 4. Build Status Monitoring

**File:** `.github/workflows/build-status.yml`

**Features:**
- Daily scheduled builds
- Test critical configurations
- Notify on failures
- Update status badge

### 5. Enhanced Cachix Workflow

**Improvements to `cachix-push.yml`:**
- Build multiple packages in parallel
- Push only on success
- Better error reporting
- Build ISOs and push to cache

### 6. Project Website Deployment

**File:** `.github/workflows/website.yml`

**Features:**
- Build landing page
- Deploy to GitHub Pages
- Separate from documentation
- Update on website changes

## Website Structure

```
website/
├── index.html           # Landing page
├── css/
│   └── style.css       # Styling
├── js/
│   └── main.js         # Interactivity
├── assets/
│   ├── logo.svg        # Marchyo logo
│   └── screenshots/    # Feature screenshots
└── build.nix           # Nix build for website
```

## GitHub Pages Configuration

**Repository Settings:**
- Source: GitHub Actions
- Custom domain: marchyo.dev (optional)

**Deployment Strategy:**
- `/` → Project website (landing page)
- `/docs/` → Documentation (mdBook)

## Implementation Order

1. ✅ Enhanced CI workflow
2. ✅ Release automation
3. ✅ Project website
4. ✅ Website deployment
5. ✅ Dependency updates
6. ✅ Build status badges
7. ✅ Update README with badges

## Success Metrics

- [ ] PRs show build status
- [ ] Releases automatically built
- [ ] ISOs available on releases
- [ ] Website live on GitHub Pages
- [ ] Documentation accessible at /docs
- [ ] Build badges in README
- [ ] Weekly dependency updates

## Timeline

**Week 1:**
- Enhanced CI workflow
- Release automation
- Build status badges

**Week 2:**
- Project website design
- Website deployment
- Dependency automation
