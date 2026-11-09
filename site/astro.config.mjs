// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://marchyo.org',
  integrations: [
    // Explicit sitemap ownership. Starlight bundles @astrojs/sitemap and only
    // injects its own when the integration is absent, so declaring it here
    // (single-language site → no i18n config needed) lets us control what ends
    // up in `sitemap-index.xml`.
    sitemap(),
    starlight({
      title: 'marchyo',
      description: 'A modular NixOS configuration flake with sensible defaults',
      // Canonical tokens + self-hosted fonts from the in-repo design system,
      // then the --sl-* bridge.
      customCss: ['./vendor/design/colors_and_type.css', './src/styles/starlight-theme.css'],
      // The tokens switch on [data-mode]; Starlight toggles [data-theme].
      head: [
        {
          tag: 'script',
          content:
            "(function(){var d=document.documentElement;" +
            "function s(){d.dataset.mode=d.dataset.theme==='dark'?'dark':'light';}" +
            "s();new MutationObserver(s).observe(d,{attributeFilter:['data-theme']});})();",
        },
      ],
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/Jylhis/marchyo' },
      ],
      editLink: {
        baseUrl: 'https://github.com/Jylhis/marchyo/edit/main/site/',
      },
      expressiveCode: {
        // Keep readable syntax themes; the frame sits on the paper/black
        // surface of the Jylhis design system.
        themes: ['github-dark', 'github-light'],
        styleOverrides: {
          codeBackground: 'var(--sl-color-bg-inline-code)',
          borderColor: 'var(--sl-color-hairline-light)',
          borderRadius: '2px',
        },
      },
      sidebar: [
        {
          label: 'Getting Started',
          items: ['docs/introduction', 'docs/quickstart'],
        },
        {
          // End-user manual — authored as flat numbered chapters in the repo-root
          // `manual/` directory, surfaced into the docs collection via the
          // `src/content/docs/manual` symlink. Autogenerate keeps the sidebar in
          // sync with the numbered files.
          label: 'Manual',
          items: [{ autogenerate: { directory: 'manual' } }],
        },
        {
          label: 'Configuration',
          items: [
            'docs/configuration/feature-flags',
            'docs/configuration/users',
            'docs/configuration/localization',
            'docs/configuration/theming',
            'docs/configuration/keyboard',
            'docs/configuration/graphics',
            'docs/configuration/default-apps',
            'docs/configuration/webapps',
            'docs/configuration/launcher',
            'docs/configuration/menu',
            'docs/configuration/notifications',
            'docs/configuration/dictation',
            'docs/configuration/hardware',
            'docs/configuration/power',
            'docs/configuration/performance',
            'docs/configuration/network',
            'docs/configuration/security',
            'docs/configuration/bees',
          ],
        },
        {
          label: 'Using Marchyo',
          items: ['docs/usage/hotkeys', 'docs/usage/updating', 'docs/usage/troubleshooting'],
        },
        {
          label: 'Guides',
          items: ['docs/guides/workstation-template', 'docs/guides/migration'],
        },
        {
          label: 'Development',
          items: [
            'docs/development/architecture',
            'docs/development/adding-modules',
            'docs/development/testing',
            'docs/development/contributing',
          ],
        },
      ],
    }),
  ],
});
