// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://marchyo.org',
  integrations: [
    starlight({
      title: 'Marchyo',
      description: 'A modular NixOS configuration flake with sensible defaults',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/Jylhis/marchyo' },
      ],
      editLink: {
        baseUrl: 'https://github.com/Jylhis/marchyo/edit/main/site/',
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
