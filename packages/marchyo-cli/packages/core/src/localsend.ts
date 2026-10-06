import dgram from "node:dgram";
import { randomBytes, randomUUID } from "node:crypto";
import { readdir, stat } from "node:fs/promises";
import { hostname, networkInterfaces } from "node:os";
import { basename, join, relative, resolve } from "node:path";

// LocalSend protocol v2 sender (https://github.com/localsend/protocol):
// multicast discovery, an HTTP register scan as fallback, and the
// prepare-upload / upload exchange. Every network effect goes through an
// injectable `fetch` or discovery function so callers can test offline.

export const LOCALSEND_PORT = 53317;
export const LOCALSEND_MULTICAST = "224.0.0.167";
export const LOCALSEND_VERSION = "2.1";
const API = "/api/localsend/v2";

export type LocalSendProtocol = "http" | "https";

export type DeviceInfo = {
  alias: string;
  version: string;
  deviceModel: string | null;
  deviceType: string | null;
  fingerprint: string;
  port: number;
  protocol: LocalSendProtocol;
  download: boolean;
};

export type Peer = DeviceInfo & { ip: string };

export type Fetch = (
  url: string,
  init: BunFetchRequestInit,
) => Promise<Response>;

// LocalSend peers serve HTTPS with a self-signed certificate.
const TLS = { rejectUnauthorized: false };

export function selfInfo(overrides: Partial<DeviceInfo> = {}): DeviceInfo {
  return {
    alias: hostname(),
    version: LOCALSEND_VERSION,
    deviceModel: "Linux",
    deviceType: "desktop",
    // Over HTTP a random string; the sender serves no certificate.
    fingerprint: randomBytes(16).toString("hex"),
    port: LOCALSEND_PORT,
    protocol: "https",
    download: false,
    ...overrides,
  };
}

export function announcePayload(
  self: DeviceInfo,
): DeviceInfo & { announce: true } {
  return { ...self, announce: true };
}

// Parse a multicast datagram or register reply into a peer. Returns null for
// malformed messages and for our own announcement (same fingerprint).
export function parsePeer(
  raw: unknown,
  ip: string,
  selfFingerprint: string,
  fallback: { port?: number; protocol?: LocalSendProtocol } = {},
): Peer | null {
  let v: unknown = raw;
  if (typeof raw === "string") {
    try {
      v = JSON.parse(raw);
    } catch {
      return null;
    }
  }
  if (typeof v !== "object" || v === null) return null;
  const o = v as Record<string, unknown>;
  if (typeof o.alias !== "string" || typeof o.fingerprint !== "string")
    return null;
  if (o.fingerprint === selfFingerprint) return null;
  const port =
    typeof o.port === "number" ? o.port : (fallback.port ?? LOCALSEND_PORT);
  const protocol =
    o.protocol === "http" || o.protocol === "https"
      ? o.protocol
      : (fallback.protocol ?? "https");
  return {
    alias: o.alias,
    version: typeof o.version === "string" ? o.version : "1.0",
    deviceModel: typeof o.deviceModel === "string" ? o.deviceModel : null,
    deviceType: typeof o.deviceType === "string" ? o.deviceType : null,
    fingerprint: o.fingerprint,
    port,
    protocol,
    download: o.download === true,
    ip,
  };
}

// First sighting wins; a device can answer both by multicast and by scan.
export function dedupePeers(peers: Peer[]): Peer[] {
  const seen = new Set<string>();
  const out: Peer[] = [];
  for (const p of peers) {
    if (seen.has(p.fingerprint)) continue;
    seen.add(p.fingerprint);
    out.push(p);
  }
  return out;
}

// IPv4 addresses of this host; peers seen on them are our own LocalSend app.
export function localIPv4(): string[] {
  const out: string[] = [];
  for (const list of Object.values(networkInterfaces())) {
    for (const a of list ?? []) {
      if (a.family === "IPv4" && !a.internal) out.push(a.address);
    }
  }
  return out;
}

export type DiscoverOptions = {
  self: DeviceInfo;
  timeoutMs: number;
};

export type Discover = (opts: DiscoverOptions) => Promise<Peer[]>;

// Announce on the multicast group and collect announcements and
// `announce: false` replies until the timeout. Binds UDP 53317 with
// reuseAddr so it coexists with a running LocalSend app; never binds TCP.
export const discoverMulticast: Discover = ({ self, timeoutMs }) =>
  new Promise((resolvePeers) => {
    const found: Peer[] = [];
    const sock = dgram.createSocket({ type: "udp4", reuseAddr: true });
    let done = false;
    const finish = () => {
      if (done) return;
      done = true;
      try {
        sock.close();
      } catch {
        // already closed
      }
      resolvePeers(found);
    };
    sock.on("error", finish);
    sock.on("message", (msg, rinfo) => {
      const p = parsePeer(
        msg.toString("utf8"),
        rinfo.address,
        self.fingerprint,
      );
      if (p) found.push(p);
    });
    try {
      sock.bind(LOCALSEND_PORT, () => {
        try {
          sock.addMembership(LOCALSEND_MULTICAST);
          const msg = Buffer.from(JSON.stringify(announcePayload(self)));
          sock.send(msg, LOCALSEND_PORT, LOCALSEND_MULTICAST);
          // A second announcement covers a dropped first datagram.
          setTimeout(
            () => {
              if (!done) sock.send(msg, LOCALSEND_PORT, LOCALSEND_MULTICAST);
            },
            Math.min(500, timeoutMs / 2),
          );
        } catch {
          finish();
        }
      });
    } catch {
      finish();
    }
    setTimeout(finish, timeoutMs);
  });

// POST /register to one address, HTTPS first, then HTTP. Returns the peer
// or null when nothing LocalSend-shaped answers.
export async function registerWith(
  ip: string,
  port: number,
  self: DeviceInfo,
  fetchImpl: Fetch = fetch,
  timeoutMs = 2000,
): Promise<Peer | null> {
  for (const protocol of ["https", "http"] as const) {
    try {
      const res = await fetchImpl(
        `${protocol}://${hostPort(ip, port)}${API}/register`,
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify(self),
          signal: AbortSignal.timeout(timeoutMs),
          tls: TLS,
        },
      );
      if (!res.ok) continue;
      const p = parsePeer(await res.json(), ip, self.fingerprint, {
        port,
        protocol,
      });
      if (p) return { ...p, port, protocol };
    } catch {
      // try the next scheme
    }
  }
  return null;
}

// The /24 of each private IPv4 interface, minus our own addresses.
export function subnetHosts(addresses: string[]): string[] {
  const own = new Set(addresses);
  const out: string[] = [];
  const seen = new Set<string>();
  for (const a of addresses) {
    const parts = a.split(".");
    if (parts.length !== 4) continue;
    const prefix = parts.slice(0, 3).join(".");
    if (seen.has(prefix)) continue;
    seen.add(prefix);
    for (let i = 1; i < 255; i++) {
      const ip = `${prefix}.${i}`;
      if (!own.has(ip)) out.push(ip);
    }
  }
  return out;
}

// Register with every host of the local /24 subnets at the default port.
// Peers answer even when our UDP port is closed, since this is outbound.
export async function scanSubnet(
  { self, timeoutMs }: DiscoverOptions,
  hosts: string[] = subnetHosts(localIPv4()),
  fetchImpl: Fetch = fetch,
): Promise<Peer[]> {
  const results = await Promise.all(
    hosts.map((ip) =>
      registerWith(ip, LOCALSEND_PORT, self, fetchImpl, timeoutMs),
    ),
  );
  return results.filter((p): p is Peer => p !== null);
}

// Multicast first; the subnet scan runs only when multicast finds nothing.
export const discoverPeers: Discover = async (opts) => {
  const own = new Set(localIPv4());
  const keep = (ps: Peer[]) => dedupePeers(ps.filter((p) => !own.has(p.ip)));
  const multicast = keep(await discoverMulticast(opts));
  if (multicast.length > 0) return multicast;
  return keep(
    await scanSubnet({ ...opts, timeoutMs: Math.min(opts.timeoutMs, 1500) }),
  );
};

export type SendFile = {
  id: string;
  path: string | null;
  fileName: string;
  size: number;
  fileType: string;
  modified?: string;
  // Inline content (clipboard text); sent as the preview and the body.
  text?: string;
};

function fileType(path: string): string {
  const t = Bun.file(path).type;
  return t.split(";")[0] || "application/octet-stream";
}

async function fileEntry(path: string, fileName: string): Promise<SendFile> {
  const st = await stat(path);
  return {
    id: randomUUID(),
    path,
    fileName,
    size: st.size,
    fileType: fileType(path),
    modified: st.mtime.toISOString(),
  };
}

// Files are sent as-is; folders recursively, named relative to the folder's
// parent so the receiver recreates the folder ("photos/2024/a.jpg").
// Symlinks and special files inside folders are skipped.
export async function expandPaths(paths: string[]): Promise<SendFile[]> {
  const out: SendFile[] = [];
  for (const p of paths) {
    const abs = resolve(p);
    const st = await stat(abs);
    if (st.isFile()) {
      out.push(await fileEntry(abs, basename(abs)));
    } else if (st.isDirectory()) {
      const root = resolve(abs, "..");
      const walk = async (dir: string): Promise<void> => {
        const entries = await readdir(dir, { withFileTypes: true });
        entries.sort((a, b) => a.name.localeCompare(b.name));
        for (const e of entries) {
          const full = join(dir, e.name);
          if (e.isDirectory()) await walk(full);
          else if (e.isFile())
            out.push(await fileEntry(full, relative(root, full)));
        }
      };
      await walk(abs);
    }
  }
  return out;
}

export function textEntry(text: string): SendFile {
  return {
    id: randomUUID(),
    path: null,
    fileName: "clipboard.txt",
    size: Buffer.byteLength(text, "utf8"),
    fileType: "text/plain",
    text,
  };
}

export function prepareUploadBody(self: DeviceInfo, files: SendFile[]) {
  const map: Record<string, Record<string, unknown>> = {};
  for (const f of files) {
    const entry: Record<string, unknown> = {
      id: f.id,
      fileName: f.fileName,
      size: f.size,
      fileType: f.fileType,
    };
    if (f.text !== undefined) entry.preview = f.text;
    if (f.modified !== undefined) entry.metadata = { modified: f.modified };
    map[f.id] = entry;
  }
  return { info: self, files: map };
}

export type StatusKind =
  | "ok"
  | "finished"
  | "invalid"
  | "pin"
  | "rejected"
  | "busy"
  | "rate-limited"
  | "receiver-error"
  | "unexpected";

export function statusKind(status: number): StatusKind {
  if (status === 200) return "ok";
  switch (status) {
    case 204:
      return "finished";
    case 400:
      return "invalid";
    case 401:
      return "pin";
    case 403:
      return "rejected";
    case 409:
      return "busy";
    case 429:
      return "rate-limited";
    case 500:
      return "receiver-error";
    default:
      return status >= 200 && status < 300 ? "ok" : "unexpected";
  }
}

const STATUS_MESSAGE: Record<StatusKind, string> = {
  ok: "accepted",
  finished: "nothing to transfer",
  invalid: "receiver rejected the request as invalid",
  pin: "receiver requires a PIN (or the PIN was wrong)",
  rejected: "receiver declined the transfer",
  busy: "receiver is busy with another transfer",
  "rate-limited": "too many requests; try again shortly",
  "receiver-error": "receiver reported an internal error",
  unexpected: "unexpected response from receiver",
};

export class LocalSendError extends Error {
  constructor(
    readonly kind: StatusKind | "network",
    readonly status: number | null,
    message: string,
  ) {
    super(message);
  }
}

export function statusError(status: number, stage: string): LocalSendError {
  const kind = statusKind(status);
  return new LocalSendError(
    kind,
    status,
    `${stage}: ${STATUS_MESSAGE[kind]} (HTTP ${status})`,
  );
}

function hostPort(ip: string, port: number): string {
  return ip.includes(":") ? `[${ip}]:${port}` : `${ip}:${port}`;
}

export function peerUrl(
  peer: Pick<Peer, "ip" | "port" | "protocol">,
  path: string,
): string {
  return `${peer.protocol}://${hostPort(peer.ip, peer.port)}${API}${path}`;
}

export type SendResult = {
  // "finished": the receiver needed no upload (204, e.g. a text message).
  status: "sent" | "finished";
  sessionId: string | null;
  sent: number;
  skipped: number;
};

export type SendOptions = {
  self: DeviceInfo;
  pin?: string;
  fetch?: Fetch;
  // The receiver prompts its user; wait this long for the decision.
  acceptTimeoutMs?: number;
  onAccepted?: () => void | Promise<void>;
  onFile?: (file: SendFile, index: number, total: number) => void;
};

export async function sendFiles(
  peer: Peer,
  files: SendFile[],
  opts: SendOptions,
): Promise<SendResult> {
  const f = opts.fetch ?? fetch;
  const q = opts.pin ? `?pin=${encodeURIComponent(opts.pin)}` : "";
  let res: Response;
  try {
    res = await f(peerUrl(peer, `/prepare-upload${q}`), {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(prepareUploadBody(opts.self, files)),
      signal: AbortSignal.timeout(opts.acceptTimeoutMs ?? 5 * 60_000),
      tls: TLS,
    });
  } catch (e) {
    throw new LocalSendError(
      "network",
      null,
      `could not reach ${peer.alias}: ${(e as Error).message}`,
    );
  }
  if (res.status === 204)
    return {
      status: "finished",
      sessionId: null,
      sent: 0,
      skipped: files.length,
    };
  if (statusKind(res.status) !== "ok")
    throw statusError(res.status, "prepare-upload");

  const body = (await res.json()) as {
    sessionId?: string;
    files?: Record<string, string>;
  };
  const sessionId = body.sessionId ?? "";
  const tokens = body.files ?? {};
  await opts.onAccepted?.();

  // The receiver may accept a subset; files without a token are skipped.
  const todo = files.filter((x) => typeof tokens[x.id] === "string");
  let sent = 0;
  for (const [i, file] of todo.entries()) {
    opts.onFile?.(file, i, todo.length);
    const params = new URLSearchParams({
      sessionId,
      fileId: file.id,
      token: tokens[file.id]!,
    });
    let up: Response;
    try {
      up = await f(peerUrl(peer, `/upload?${params}`), {
        method: "POST",
        headers: { "content-type": file.fileType },
        body: file.text !== undefined ? file.text : Bun.file(file.path!),
        tls: TLS,
      });
    } catch (e) {
      await cancel(peer, sessionId, f);
      throw new LocalSendError(
        "network",
        null,
        `upload of ${file.fileName} failed: ${(e as Error).message}`,
      );
    }
    if (!up.ok) {
      await cancel(peer, sessionId, f);
      throw statusError(up.status, `upload ${file.fileName}`);
    }
    sent++;
  }
  return { status: "sent", sessionId, sent, skipped: files.length - sent };
}

async function cancel(peer: Peer, sessionId: string, f: Fetch): Promise<void> {
  try {
    await f(
      peerUrl(peer, `/cancel?sessionId=${encodeURIComponent(sessionId)}`),
      {
        method: "POST",
        signal: AbortSignal.timeout(2000),
        tls: TLS,
      },
    );
  } catch {
    // best effort
  }
}

// `--to` accepts an IPv4 address with an optional port.
export function parseAddress(
  target: string,
): { ip: string; port: number } | null {
  const m = /^(\d{1,3}(?:\.\d{1,3}){3})(?::(\d{1,5}))?$/.exec(target);
  if (!m) return null;
  if (m[1]!.split(".").some((o) => Number(o) > 255)) return null;
  const port = m[2] !== undefined ? Number(m[2]) : LOCALSEND_PORT;
  if (port < 1 || port > 65535) return null;
  return { ip: m[1]!, port };
}

export function matchPeer(peers: Peer[], target: string): Peer | null {
  const t = target.toLowerCase();
  return (
    peers.find((p) => p.alias.toLowerCase() === t || p.ip === target) ?? null
  );
}
