/**
 * Static endpoint that generates llms.txt (https://llmstxt.org) at build time:
 * one line for each page of the manual and the documentation, with its
 * description, so that an AI agent finds the right page without a crawl.
 */
import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

const sections: Array<[heading: string, prefix: string]> = [
  ['Manual', 'manual/'],
  ['Configuration', 'docs/configuration/'],
  ['Guides', 'docs/guides/'],
  ['Documentation', 'docs/'],
];

export const GET: APIRoute = async ({ site }) => {
  const pages = (await getCollection('docs', ({ data }) => !data.draft)).sort((a, b) =>
    a.id.localeCompare(b.id),
  );
  const line = (page: (typeof pages)[number]) => {
    const url = new URL(`/${page.id}/`, site).href;
    const description = page.data.description ? `: ${page.data.description}` : '';
    return `- [${page.data.title}](${url})${description}`;
  };

  // Each page goes under the first section whose prefix matches.
  const rest = new Set(pages);
  const blocks = sections.map(([heading, prefix]) => {
    const own = [...rest].filter((page) => page.id.startsWith(prefix));
    own.forEach((page) => rest.delete(page));
    return [heading, own] as const;
  });
  const order = ['Documentation', 'Manual', 'Configuration', 'Guides'];
  const body = order
    .map((heading) => blocks.find(([name]) => name === heading)!)
    .filter(([, own]) => own.length > 0)
    .map(([heading, own]) => `## ${heading}\n\n${own.map(line).join('\n')}`)
    .join('\n\n');

  const text = `# Marchyo

> Marchyo is a modular NixOS configuration flake: one flake input gives a full
> Hyprland desktop, a development toolchain and a themed user environment, with
> Home Manager, behind feature flags under the \`marchyo.*\` option namespace.

Start a system with \`nix flake init -t github:Jylhis/marchyo#workstation\`. The
source is at https://github.com/Jylhis/marchyo (MIT licence).

${body}

## Optional

- [Source code](https://github.com/Jylhis/marchyo): the flake, its modules and the tests
- [Sitemap](${new URL('/sitemap-index.xml', site).href}): every page of the site
`;

  return new Response(text, { headers: { 'Content-Type': 'text/plain; charset=utf-8' } });
};
