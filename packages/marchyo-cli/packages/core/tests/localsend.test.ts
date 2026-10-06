import { test, expect } from "bun:test";
import { mkdirSync, mkdtempSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  type Fetch,
  type Peer,
  LOCALSEND_PORT,
  LocalSendError,
  announcePayload,
  dedupePeers,
  expandPaths,
  matchPeer,
  parseAddress,
  parsePeer,
  prepareUploadBody,
  registerWith,
  scanSubnet,
  selfInfo,
  sendFiles,
  statusKind,
  subnetHosts,
  textEntry,
} from "../src/localsend.ts";

const SELF = selfInfo({ alias: "host", fingerprint: "self-fp" });

function peer(over: Partial<Peer> = {}): Peer {
  return {
    alias: "Phone",
    version: "2.1",
    deviceModel: "Pixel",
    deviceType: "mobile",
    fingerprint: "peer-fp",
    port: LOCALSEND_PORT,
    protocol: "https",
    download: false,
    ip: "192.168.1.20",
    ...over,
  };
}

type Call = { url: string; init: BunFetchRequestInit };

// A recording fetch that answers from a route table keyed by URL path.
function fakeFetch(
  routes: Record<string, (call: Call) => Response | Promise<Response>>,
): { fetch: Fetch; calls: Call[] } {
  const calls: Call[] = [];
  const f: Fetch = async (url, init) => {
    const call = { url, init };
    calls.push(call);
    const path = new URL(url).pathname;
    const route = routes[path];
    if (!route) throw new Error(`connection refused: ${url}`);
    return route(call);
  };
  return { fetch: f, calls };
}

test("announcement carries the device info and announce: true", () => {
  const a = announcePayload(SELF);
  expect(a).toEqual({
    alias: "host",
    version: "2.1",
    deviceModel: "Linux",
    deviceType: "desktop",
    fingerprint: "self-fp",
    port: 53317,
    protocol: "https",
    download: false,
    announce: true,
  });
});

test("selfInfo generates a random fingerprint per run", () => {
  expect(selfInfo().fingerprint).not.toBe(selfInfo().fingerprint);
});

test("parsePeer accepts announcements and ignores our own and malformed ones", () => {
  const msg = JSON.stringify({
    ...announcePayload(SELF),
    alias: "Phone",
    fingerprint: "x",
    protocol: "http",
    port: 5000,
  });
  expect(parsePeer(msg, "10.0.0.5", "self-fp")).toMatchObject({
    alias: "Phone",
    ip: "10.0.0.5",
    port: 5000,
    protocol: "http",
  });
  expect(
    parsePeer(JSON.stringify(announcePayload(SELF)), "10.0.0.6", "self-fp"),
  ).toBeNull();
  expect(parsePeer("not json", "10.0.0.7", "self-fp")).toBeNull();
  expect(parsePeer({ alias: 1 }, "10.0.0.7", "self-fp")).toBeNull();
});

test("parsePeer falls back to the scanned port and scheme for register replies", () => {
  // The register response has no port or protocol.
  const p = parsePeer(
    { alias: "Laptop", fingerprint: "f", version: "2.0" },
    "10.0.0.8",
    "self-fp",
    {
      port: 53317,
      protocol: "http",
    },
  );
  expect(p).toMatchObject({ port: 53317, protocol: "http", deviceType: null });
});

test("dedupePeers keeps the first sighting per fingerprint", () => {
  const a = peer({ ip: "10.0.0.1" });
  const b = peer({ ip: "10.0.0.2" });
  const c = peer({ fingerprint: "other", alias: "Tablet" });
  expect(dedupePeers([a, b, c])).toEqual([a, c]);
});

test("matchPeer finds by alias (case-insensitive) or ip", () => {
  const ps = [
    peer(),
    peer({ alias: "Tablet", fingerprint: "t", ip: "10.0.0.9" }),
  ];
  expect(matchPeer(ps, "phone")?.ip).toBe("192.168.1.20");
  expect(matchPeer(ps, "10.0.0.9")?.alias).toBe("Tablet");
  expect(matchPeer(ps, "nope")).toBeNull();
});

test("parseAddress takes IPv4 with an optional port", () => {
  expect(parseAddress("192.168.1.2")).toEqual({
    ip: "192.168.1.2",
    port: 53317,
  });
  expect(parseAddress("10.0.0.1:8080")).toEqual({ ip: "10.0.0.1", port: 8080 });
  expect(parseAddress("Pixel")).toBeNull();
  expect(parseAddress("300.1.1.1")).toBeNull();
});

test("subnetHosts covers each /24 once, minus our own addresses", () => {
  const hosts = subnetHosts(["192.168.1.10", "192.168.1.11"]);
  expect(hosts.length).toBe(252);
  expect(hosts).not.toContain("192.168.1.10");
  expect(hosts).toContain("192.168.1.1");
  expect(hosts).toContain("192.168.1.254");
});

test("registerWith tries https, then http, and returns the peer", async () => {
  const { fetch, calls } = fakeFetch({
    "/api/localsend/v2/register": ({ url }) =>
      url.startsWith("https:")
        ? Promise.reject(new Error("tls"))
        : Response.json({ alias: "Phone", fingerprint: "pf", version: "2.1" }),
  });
  const p = await registerWith("10.0.0.4", 53317, SELF, fetch);
  expect(calls.map((c) => c.url)).toEqual([
    "https://10.0.0.4:53317/api/localsend/v2/register",
    "http://10.0.0.4:53317/api/localsend/v2/register",
  ]);
  expect(JSON.parse(calls[0]!.init.body as string)).toMatchObject({
    alias: "host",
    fingerprint: "self-fp",
  });
  expect(p).toMatchObject({
    alias: "Phone",
    ip: "10.0.0.4",
    protocol: "http",
    port: 53317,
  });
});

test("scanSubnet returns only hosts that answer", async () => {
  const f: Fetch = async (url) => {
    if (url.startsWith("https://10.0.0.3:"))
      return Response.json({ alias: "A", fingerprint: "a" });
    throw new Error("refused");
  };
  const ps = await scanSubnet(
    { self: SELF, timeoutMs: 100 },
    ["10.0.0.2", "10.0.0.3"],
    f,
  );
  expect(ps.map((p) => p.ip)).toEqual(["10.0.0.3"]);
});

function tree(): string {
  const dir = mkdtempSync(join(tmpdir(), "marchyo-localsend-"));
  mkdirSync(join(dir, "trip", "day1"), { recursive: true });
  writeFileSync(join(dir, "trip", "a.jpg"), "aaa");
  writeFileSync(join(dir, "trip", "day1", "b.txt"), "bb");
  symlinkSync(join(dir, "trip", "a.jpg"), join(dir, "trip", "link.jpg"));
  writeFileSync(join(dir, "single.pdf"), "x");
  return dir;
}

test("expandPaths sends folders recursively with relative names", async () => {
  const dir = tree();
  const files = await expandPaths([join(dir, "single.pdf"), join(dir, "trip")]);
  expect(files.map((f) => f.fileName)).toEqual([
    "single.pdf",
    "trip/a.jpg",
    "trip/day1/b.txt",
  ]);
  expect(files.map((f) => f.size)).toEqual([1, 3, 2]);
  expect(files[1]!.fileType).toBe("image/jpeg");
  expect(new Set(files.map((f) => f.id)).size).toBe(3);
});

test("prepareUploadBody follows the v2 schema", async () => {
  const dir = tree();
  const [file] = await expandPaths([join(dir, "single.pdf")]);
  const text = textEntry("hello");
  const body = prepareUploadBody(SELF, [file!, text]);
  expect(body.info).toEqual(SELF);
  expect(body.files[file!.id]).toEqual({
    id: file!.id,
    fileName: "single.pdf",
    size: 1,
    fileType: "application/pdf",
    metadata: { modified: file!.modified },
  });
  expect(body.files[text.id]).toEqual({
    id: text.id,
    fileName: "clipboard.txt",
    size: 5,
    fileType: "text/plain",
    preview: "hello",
  });
});

test("statusKind maps the prepare-upload statuses", () => {
  expect(statusKind(200)).toBe("ok");
  expect(statusKind(204)).toBe("finished");
  expect(statusKind(400)).toBe("invalid");
  expect(statusKind(401)).toBe("pin");
  expect(statusKind(403)).toBe("rejected");
  expect(statusKind(409)).toBe("busy");
  expect(statusKind(429)).toBe("rate-limited");
  expect(statusKind(500)).toBe("receiver-error");
  expect(statusKind(418)).toBe("unexpected");
});

test("sendFiles prepares, then uploads each accepted file with its token", async () => {
  const dir = tree();
  const files = await expandPaths([join(dir, "trip")]);
  const uploads: { params: URLSearchParams; body: string }[] = [];
  let accepted = false;
  const { fetch, calls } = fakeFetch({
    "/api/localsend/v2/prepare-upload": () =>
      // Accept only the first file.
      Response.json({ sessionId: "s1", files: { [files[0]!.id]: "tok0" } }),
    "/api/localsend/v2/upload": async ({ url, init }) => {
      uploads.push({
        params: new URL(url).searchParams,
        body: await new Response(init.body as Blob).text(),
      });
      return new Response(null, { status: 200 });
    },
  });
  const r = await sendFiles(peer(), files, {
    self: SELF,
    pin: "1234",
    fetch,
    onAccepted: () => {
      accepted = true;
    },
  });
  expect(calls[0]!.url).toBe(
    "https://192.168.1.20:53317/api/localsend/v2/prepare-upload?pin=1234",
  );
  expect(calls[0]!.init.tls).toEqual({ rejectUnauthorized: false });
  expect(accepted).toBe(true);
  expect(uploads).toHaveLength(1);
  expect(Object.fromEntries(uploads[0]!.params)).toEqual({
    sessionId: "s1",
    fileId: files[0]!.id,
    token: "tok0",
  });
  expect(uploads[0]!.body).toBe("aaa");
  expect(r).toEqual({ status: "sent", sessionId: "s1", sent: 1, skipped: 1 });
});

test("sendFiles treats 204 as finished without uploading", async () => {
  const { fetch, calls } = fakeFetch({
    "/api/localsend/v2/prepare-upload": () =>
      new Response(null, { status: 204 }),
  });
  const r = await sendFiles(peer(), [textEntry("hi")], { self: SELF, fetch });
  expect(r.status).toBe("finished");
  expect(calls).toHaveLength(1);
});

for (const [status, kind] of [
  [401, "pin"],
  [403, "rejected"],
  [409, "busy"],
  [429, "rate-limited"],
] as const) {
  test(`sendFiles raises ${kind} on HTTP ${status}`, async () => {
    const { fetch } = fakeFetch({
      "/api/localsend/v2/prepare-upload": () => new Response(null, { status }),
    });
    const e = await sendFiles(peer(), [textEntry("hi")], {
      self: SELF,
      fetch,
    }).catch((x) => x);
    expect(e).toBeInstanceOf(LocalSendError);
    expect((e as LocalSendError).kind).toBe(kind);
    expect((e as LocalSendError).status).toBe(status);
  });
}

test("a failed upload cancels the session", async () => {
  const t = textEntry("hi");
  const { fetch, calls } = fakeFetch({
    "/api/localsend/v2/prepare-upload": () =>
      Response.json({ sessionId: "s2", files: { [t.id]: "k" } }),
    "/api/localsend/v2/upload": () => new Response(null, { status: 500 }),
    "/api/localsend/v2/cancel": () => new Response(null, { status: 200 }),
  });
  const e = await sendFiles(peer(), [t], { self: SELF, fetch }).catch((x) => x);
  expect((e as LocalSendError).kind).toBe("receiver-error");
  expect(calls.at(-1)!.url).toBe(
    "https://192.168.1.20:53317/api/localsend/v2/cancel?sessionId=s2",
  );
});
