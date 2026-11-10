// The manual links to its chapters as `./NN-name.md` so the links work on
// GitHub. Starlight serves each chapter at /manual/NN-name/, so rewrite them.
const chapter = /^(?:\.\/)?(\d\d-[\w-]+)\.md(#.*)?$/;

// Typed loosely: satteri's plugin type demands every visitor key.
/** @type {any} */
export default {
  name: 'manual-links',
  link(node, ctx) {
    const m = chapter.exec(node.url);
    if (m) ctx.setProperty(node, 'url', `../${m[1]}/${m[2] ?? ''}`);
  },
};
