// Cloudflare Web Analytics for the marchyo.org zone: cookieless, so no consent
// banner. The token is the public site token and appears in every page. The
// zone has automatic setup on, but the edge does not inject the beacon into
// the responses of an assets-only Worker, so the pages carry the snippet.
export const beaconSrc = 'https://static.cloudflareinsights.com/beacon.min.js';
export const beaconData = JSON.stringify({ token: '5038f529ea9b482fb8418249fad2a7c4' });

// Link preview image (1200x630), an absolute URL as Open Graph requires.
export const ogImage = 'https://marchyo.org/og.png';
export const ogImageAlt = 'marchyo: a modular NixOS configuration flake with sensible defaults';
