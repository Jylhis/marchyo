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
    // up in `sitemap-index.xml`. `/search/` is a client-rendered demo with
    // hardcoded sample data and is marked noindex, so keep it out of the map.
    sitemap({
      filter: (page) => !page.endsWith('/search/'),
    }),
    starlight({
      title: 'marchyo',
      description: 'A modular NixOS configuration flake with sensible defaults',
      customCss: ['./src/styles/starlight-theme.css'],
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/Jylhis/marchyo' },
      ],
      editLink: {
        baseUrl: 'https://github.com/Jylhis/marchyo/edit/main/site/',
      },
      expressiveCode: {
        // Keep readable syntax themes but warm the frame to sit on the
        // paper/roast surface, matching the Jylhis design system.
        themes: ['github-dark', 'github-light'],
        styleOverrides: {
          codeBackground: 'var(--sl-color-bg-inline-code)',
          borderColor: 'var(--sl-color-hairline-light)',
          borderRadius: '4px',
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
            'docs/configuration/launcher',
            'docs/configuration/ai',
            'docs/configuration/dictation',
            'docs/configuration/hardware',
            'docs/configuration/performance',
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
