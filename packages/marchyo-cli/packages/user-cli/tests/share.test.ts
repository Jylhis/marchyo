import { test, expect, spyOn } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { type Runtime } from "@marchyo/core";
import { type Fetch, type Peer } from "@marchyo/core/localsend";
import { type ShareDeps, runShare } from "../src/commands/utilities.ts";

// runShare with every network and desktop effect faked: nothing here opens a
// socket, so the tests stay offline and never reach a real LocalSend device.

const RT: Runtime = {
  format: "text",
  noColor: true,
  forceColor: false,
  plain: true,
  noAnimation: true,
  noInput: true,
  quiet: false,
  verbose: 0,
};

function peer(alias: string, ip: string): Peer {
  return {
    alias,
    version: "2.1",
    deviceModel: null,
    deviceType: "mobile",
    fingerprint: `fp-${alias}`,
    port: 53317,
    protocol: "https",
    download: false,
    ip,
  };
}

function file(): string {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-share-"));
  const p = join(dir, "a.txt");
  writeFileSync(p, "hello");
  return p;
}

// Answers prepare-upload with `status` (tokens for every file on 200).
function receiver(status = 200): { fetch: Fetch; hosts: string[] } {
  const hosts: string[] = [];
  const f: Fetch = async (url, init) => {
    const u = new URL(url);
    hosts.push(u.hostname);
    if (u.pathname.endsWith("/prepare-upload")) {
      if (status !== 200) return new Response(null, { status });
      const body = JSON.parse(init.body as string) as {
        files: Record<string, unknown>;
      };
      return Response.json({
        sessionId: "s",
        files: Object.fromEntries(
          Object.keys(body.files).map((id) => [id, "tok"]),
        ),
      });
    }
    return new Response(null, { status: 200 });
  };
  return { fetch: f, hosts };
}

function deps(
  over: Partial<ShareDeps> = {},
): ShareDeps & { notes: string[]; prompts: string[] } {
  const notes: string[] = [];
  const prompts: string[] = [];
  return {
    discover: async () => [],
    register: async () => null,
    fetch: receiver().fetch,
    interactive: false,
    choose: async (header) => {
      prompts.push(header);
      return null;
    },
    pickPath: async () => null,
    readClipboard: async () => null,
    notify: async (_u, _s, body) => {
      notes.push(body);
    },
    openLocalSend: () => true,
    notes,
    prompts,
    ...over,
  };
}

function stderrOf(): { text: () => string; restore: () => void } {
  const chunks: string[] = [];
  const spy = spyOn(process.stderr, "write").mockImplementation(
    (c: string | Uint8Array) => {
      chunks.push(String(c));
      return true;
    },
  );
  return { text: () => chunks.join(""), restore: () => spy.mockRestore() };
}

test("no peers: errors with a hint and does not prompt under --no-input", async () => {
  const d = deps();
  const err = stderrOf();
  const code = await runShare(RT, [file()], {}, d);
  err.restore();
  expect(code).toBe(1);
  expect(err.text()).toContain("no LocalSend devices found");
  expect(err.text()).toContain("--to <ip>");
  expect(d.prompts).toEqual([]);
});

test("no peers, interactive: offers to open LocalSend", async () => {
  let opened = false;
  const d = deps({
    interactive: true,
    choose: async () => "Open LocalSend",
    openLocalSend: () => {
      opened = true;
      return true;
    },
  });
  const err = stderrOf();
  const code = await runShare(RT, [file()], {}, d);
  err.restore();
  expect(code).toBe(1);
  expect(opened).toBe(true);
});

test("one peer: sends without asking and notifies accepted + done", async () => {
  const r = receiver();
  const d = deps({
    discover: async () => [peer("Phone", "10.0.0.2")],
    fetch: r.fetch,
  });
  const err = stderrOf();
  const code = await runShare(RT, [file()], {}, d);
  err.restore();
  expect(code).toBe(0);
  expect(r.hosts).toEqual(["10.0.0.2", "10.0.0.2"]);
  expect(d.notes).toEqual(["Phone accepted", "sent 1 file(s) to Phone"]);
});

test("several peers under --no-input: asks for --to", async () => {
  const d = deps({
    discover: async () => [
      peer("Phone", "10.0.0.2"),
      peer("Tablet", "10.0.0.3"),
    ],
  });
  const err = stderrOf();
  const code = await runShare(RT, [file()], {}, d);
  err.restore();
  expect(code).toBe(1);
  expect(err.text()).toContain("pick one with --to");
  expect(err.text()).toContain("Tablet (10.0.0.3)");
});

test("several peers, interactive: the picked one receives", async () => {
  const r = receiver();
  const d = deps({
    interactive: true,
    discover: async () => [
      peer("Phone", "10.0.0.2"),
      peer("Tablet", "10.0.0.3"),
    ],
    choose: async (_h, options) => options[1] ?? null,
    fetch: r.fetch,
  });
  const err = stderrOf();
  const code = await runShare(RT, [file()], {}, d);
  err.restore();
  expect(code).toBe(0);
  expect(r.hosts[0]).toBe("10.0.0.3");
});

test("--to <alias> matches a discovered peer", async () => {
  const r = receiver();
  const d = deps({
    discover: async () => [
      peer("Phone", "10.0.0.2"),
      peer("Tablet", "10.0.0.3"),
    ],
    fetch: r.fetch,
  });
  const err = stderrOf();
  const code = await runShare(RT, [file()], { to: "tablet" }, d);
  err.restore();
  expect(code).toBe(0);
  expect(r.hosts[0]).toBe("10.0.0.3");
});

test("--to <ip> skips discovery", async () => {
  let discovered = false;
  const d = deps({
    discover: async () => {
      discovered = true;
      return [];
    },
    register: async (ip) => peer("Laptop", ip),
  });
  const err = stderrOf();
  const code = await runShare(RT, [file()], { to: "10.0.0.7" }, d);
  err.restore();
  expect(code).toBe(0);
  expect(discovered).toBe(false);
});

test("a rejected transfer notifies and exits 1", async () => {
  const d = deps({
    discover: async () => [peer("Phone", "10.0.0.2")],
    fetch: receiver(403).fetch,
  });
  const err = stderrOf();
  const code = await runShare(RT, [file()], {}, d);
  err.restore();
  expect(code).toBe(1);
  expect(d.notes).toEqual(["Phone declined the transfer"]);
  expect(err.text()).toContain("declined");
});

test("a PIN prompt from the receiver hints at --pin", async () => {
  const d = deps({
    discover: async () => [peer("Phone", "10.0.0.2")],
    fetch: receiver(401).fetch,
  });
  const err = stderrOf();
  const code = await runShare(RT, [file()], {}, d);
  err.restore();
  expect(code).toBe(1);
  expect(err.text()).toContain("--pin");
});

test("menu Clipboard sends the clipboard text as a message", async () => {
  let body: {
    files: Record<string, { fileType: string; preview?: string }>;
  } | null = null;
  const f: Fetch = async (url, init) => {
    if (url.includes("/prepare-upload")) body = JSON.parse(init.body as string);
    return new Response(null, { status: 204 });
  };
  const d = deps({
    interactive: true,
    choose: async (header) => (header === "Share" ? "Clipboard" : null),
    readClipboard: async () => "hello there",
    discover: async () => [peer("Phone", "10.0.0.2")],
    fetch: f,
  });
  const err = stderrOf();
  const code = await runShare(RT, [], {}, d);
  err.restore();
  expect(code).toBe(0);
  expect(Object.values(body!.files)).toEqual([
    expect.objectContaining({ fileType: "text/plain", preview: "hello there" }),
  ]);
  expect(d.notes).toEqual(["delivered to Phone"]);
});
