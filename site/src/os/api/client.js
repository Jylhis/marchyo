// Local-only data layer. Implements the app's data surface against
// `localStorage`: `api.entities.<Name>.{list,get,create,update,delete,filter}`
// and `api.auth.me()`. Pages/components import `{ api }` from '@/api/client'.
// No network, no accounts: everything lives in the browser. Swap this file for
// a real backend client to go server-backed.

import seedOptions from "../data/marchyo-options.json";

const NS = "marchyo-os";
const isBrowser = typeof window !== "undefined" && !!window.localStorage;

const memory = new Map(); // SSR/build-time fallback when localStorage is absent.

function read(name) {
  const key = `${NS}:${name}`;
  if (!isBrowser) return memory.get(key) ?? [];
  try {
    return JSON.parse(window.localStorage.getItem(key) ?? "[]");
  } catch {
    return [];
  }
}

function write(name, rows) {
  const key = `${NS}:${name}`;
  if (!isBrowser) {
    memory.set(key, rows);
    return;
  }
  window.localStorage.setItem(key, JSON.stringify(rows));
}

function uid() {
  if (isBrowser && window.crypto?.randomUUID) return window.crypto.randomUUID();
  return `id_${Date.now().toString(36)}_${Math.random().toString(36).slice(2, 10)}`;
}

function sortRows(rows, sort) {
  if (!sort) return rows;
  const desc = sort.startsWith("-");
  const field = desc ? sort.slice(1) : sort;
  return [...rows].sort((a, b) => {
    const av = a?.[field];
    const bv = b?.[field];
    if (av === bv) return 0;
    if (av === undefined || av === null) return 1;
    if (bv === undefined || bv === null) return -1;
    const cmp = av < bv ? -1 : 1;
    return desc ? -cmp : cmp;
  });
}

function matches(row, query) {
  return Object.entries(query ?? {}).every(([k, v]) => row?.[k] === v);
}

function makeEntity(name) {
  return {
    async list(sort, limit) {
      const rows = sortRows(read(name), sort);
      return typeof limit === "number" ? rows.slice(0, limit) : rows;
    },
    async filter(query, sort, limit) {
      const rows = sortRows(
        read(name).filter((r) => matches(r, query)),
        sort,
      );
      return typeof limit === "number" ? rows.slice(0, limit) : rows;
    },
    async get(id) {
      return read(name).find((r) => r.id === id) ?? null;
    },
    async create(data) {
      const now = new Date().toISOString();
      const row = { id: uid(), created_date: now, updated_date: now, ...data };
      const rows = read(name);
      rows.push(row);
      write(name, rows);
      return row;
    },
    async update(id, data) {
      const rows = read(name);
      const i = rows.findIndex((r) => r.id === id);
      if (i === -1) throw new Error(`${name} ${id} not found`);
      rows[i] = { ...rows[i], ...data, updated_date: new Date().toISOString() };
      write(name, rows);
      return rows[i];
    },
    async delete(id) {
      write(
        name,
        read(name).filter((r) => r.id !== id),
      );
      return { id };
    },
  };
}

const ENTITY_NAMES = [
  "Machine",
  "MarchyoOption",
  "OptionTemplate",
  "GitRepo",
  "ConfigProfile",
  "User",
];

const entities = Object.fromEntries(
  ENTITY_NAMES.map((n) => [n, makeEntity(n)]),
);

// First-run seed: the MarchyoOption catalogue ships with the app, generated
// from the real marchyo flake's module options (scripts/os/seed-options.mjs).
// Only when the store has never been written — an emptied store stays empty.
function seedMarchyoOptions() {
  const key = `${NS}:MarchyoOption`;
  const unseeded = isBrowser
    ? window.localStorage.getItem(key) === null
    : !memory.has(key);
  if (!unseeded) return;
  const now = new Date().toISOString();
  write(
    "MarchyoOption",
    seedOptions.map((o) => ({ ...o, created_date: now, updated_date: now })),
  );
}
seedMarchyoOptions();

// Single local "user"; the app only ever reads auth.me() (no real login).
const LOCAL_USER = { id: "local", email: "local@localhost", role: "admin" };

export const api = {
  entities,
  auth: {
    async me() {
      return LOCAL_USER;
    },
  },
};
