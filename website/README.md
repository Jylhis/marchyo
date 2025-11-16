# Marchyo Website

This directory contains the Marchyo project website (landing page).

## Structure

```
website/
├── index.html       # Main landing page
├── css/
│   └── style.css   # Styling (Modus Vivendi Tinted theme)
├── js/
│   └── main.js     # JavaScript for interactivity
├── assets/         # Images and static assets
└── default.nix     # Nix build configuration
```

## Building

### Build Website Only

```bash
nix build .#website
```

### Build Combined Site (Website + Documentation)

```bash
nix build .#site
```

This creates a combined site with:
- Website at `/`
- Documentation at `/docs/`

### Serve Locally

```bash
# Serve website only
nix run .#serve-website

# Serve combined site (recommended)
nix run .#serve-site
```

## Deployment

The website is automatically deployed to GitHub Pages when changes are pushed to the `main` branch.

**Workflow:** `.github/workflows/deploy-site.yml`

**Deployment:**
- Website: https://jylhis.github.io/marchyo/
- Documentation: https://jylhis.github.io/marchyo/docs/

## Customization

### Colors

The website uses the Modus Vivendi Tinted color scheme defined in `css/style.css`:

```css
:root {
    --color-bg: #0d0e1c;
    --color-accent: #2fafff;
    /* ... more colors */
}
```

### Content

Edit `index.html` to modify:
- Hero section
- Features
- Quick start steps
- Download options
- Showcase
- Community links

### Styling

Modify `css/style.css` for:
- Layout changes
- Color adjustments
- Typography
- Responsive breakpoints

### JavaScript

Edit `js/main.js` for:
- Scroll animations
- Interactive elements
- Navigation behavior

## Adding Assets

Place images and other assets in the `assets/` directory:

```
assets/
├── logo.svg
├── screenshots/
│   ├── desktop.png
│   └── terminal.png
└── icons/
    └── favicon.ico
```

Reference in HTML:

```html
<img src="assets/logo.svg" alt="Marchyo Logo">
```

## Design

**Framework:** Pure HTML/CSS/JS (no framework dependencies)
**Theme:** Modus Vivendi Tinted (matching Marchyo defaults)
**Fonts:** System fonts (fallback to sans-serif)
**Icons:** Emoji (no icon library needed)

## Browser Support

- Modern browsers (Chrome, Firefox, Safari, Edge)
- Mobile responsive
- Progressive enhancement (works without JS)

## License

Same as Marchyo project (see root LICENSE file)
