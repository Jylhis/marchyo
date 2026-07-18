// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://marchyo.org',
  integrations: [
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
          label: 'Configuration',
          items: [
            'docs/configuration/feature-flags',
            'docs/configuration/users',
            'docs/configuration/localization',
            'docs/configuration/theming',
            'docs/configuration/keyboard',
            'docs/configuration/graphics',
            'docs/configuration/default-apps',
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
