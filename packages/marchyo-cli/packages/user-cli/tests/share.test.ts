import { test, expect, spyOn } from "bun:test";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { type Runtime } from "@marchyo/core";
import { type Fetch, type Peer } from "@marchyo/core/localsend";
import { type ShareDeps, type TailscaleDeps, runShare } from "../src/commands/utilities.ts";

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

// A fake tailscale CLI: records argv, answers `file cp --targets` from `targets`.
function fakeTailscale(
  over: { available?: boolean; code?: number; stderr?: string; targets?: string[] } = {},
): TailscaleDeps & { calls: string[][] } {
  const calls: string[][] = [];
  return {
    calls,
    available: () => over.available ?? false,
    run: async (argv) => {
      calls.push(argv);
      if (argv.includes("--targets")) {
        const out = (over.targets ?? []).map((n) => `100.64.0.1\t${n}\tidle`).join("\n");
        return { code: 0, stdout: out, stderr: "" };
      }
      return { code: over.code ?? 0, stdout: "", stderr: over.stderr ?? "" };
    },
  };
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
    tailscale: fakeTailscale(),
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

test("--tailscale sends via tailscale file cp and skips LocalSend", async () => {
  const ts = fakeTailscale({ available: true });
  const d = deps({ tailscale: ts, discover: async () => [peer("Phone", "10.0.0.2")] });
  const f = file();
  const err = stderrOf();
  const code = await runShare(RT, [f], { tailscale: "laptop.tail.ts.net" }, d);
  err.restore();
  expect(code).toBe(0);
  expect(ts.calls).toEqual([
    ["file", "cp", "--update-interval=0", "--", f, "laptop.tail.ts.net:"],
  ]);
  expect(d.notes).toEqual(["sent 1 file(s) to laptop over Taildrop"]);
});

test("--tailscale reports the tailscale error", async () => {
  const ts = fakeTailscale({ available: true, code: 1, stderr: "no such peer" });
  const d = deps({ tailscale: ts });
  const err = stderrOf();
  const code = await runShare(RT, [file()], { tailscale: "ghost" }, d);
  err.restore();
  expect(code).toBe(1);
  expect(err.text()).toContain("no such peer");
});

test("--tailscale without tailscale on PATH fails", async () => {
  const d = deps();
  const err = stderrOf();
  const code = await runShare(RT, [file()], { tailscale: "laptop" }, d);
  err.restore();
  expect(code).toBe(1);
  expect(err.text()).toContain("tailscale not found");
});

test("--tailscale-receive runs tailscale file get into the directory", async () => {
  const ts = fakeTailscale({ available: true });
  const d = deps({ tailscale: ts });
  const dir = mkdtempSync(join(tmpdir(), "marchyo-taildrop-"));
  const err = stderrOf();
  const code = await runShare(RT, [dir], { tailscaleReceive: true }, d);
  err.restore();
  expect(code).toBe(0);
  expect(ts.calls).toEqual([["file", "get", "--conflict=rename", dir]]);
});

test("share menu offers Taildrop only when tailscale is available", async () => {
  const seen: string[][] = [];
  const mk = (available: boolean) =>
    deps({
      interactive: true,
      tailscale: fakeTailscale({ available }),
      choose: async (_h, options) => {
        seen.push(options);
        return null;
      },
    });
  await runShare(RT, [], {}, mk(false));
  await runShare(RT, [], {}, mk(true));
  expect(seen[0]).not.toContain("Taildrop");
  expect(seen[1]).toContain("Taildrop");
});

test("Taildrop menu path picks a peer from --targets and sends", async () => {
  const ts = fakeTailscale({ available: true, targets: ["laptop", "phone"] });
  const f = file();
  const d = deps({
    interactive: true,
    tailscale: ts,
    choose: async (h, options) => (h === "Share" ? "Taildrop" : (options[1] ?? null)),
    pickPath: async () => f,
  });
  const err = stderrOf();
  const code = await runShare(RT, [], {}, d);
  err.restore();
  expect(code).toBe(0);
  expect(ts.calls.at(-1)).toEqual(["file", "cp", "--update-interval=0", "--", f, "phone:"]);
});
