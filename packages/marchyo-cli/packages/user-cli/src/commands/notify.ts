import {
  NOTIFY_USAGE,
  NotifyUsageError,
  type NotifyDeps,
  type Runtime,
  defaultNotifyDeps,
  err,
  hint,
  parseNotifyArgs,
  sendNotification,
  tr,
} from "@marchyo/core";

// `marchyo notify`: the omarchy-notification-send surface over D-Bus. The
// arguments reach this function untouched (see cli.tsx), because commander
// would read --exec, --action and the flags after the headline as its own.

export async function runNotify(
  rt: Runtime,
  args: string[],
  deps: NotifyDeps = defaultNotifyDeps(),
): Promise<number> {
  let req;
  try {
    req = parseNotifyArgs(args);
  } catch (e) {
    if (!(e instanceof NotifyUsageError)) throw e;
    for (const line of e.lines) err(rt, line);
    if (e.showUsage) hint(rt, `Usage: ${NOTIFY_USAGE}`);
    return 2;
  }
  const sent = await sendNotification(req, deps);
  if (!sent.ok) {
    err(rt, tr("notify.sendFailed", sent.error ?? ""));
    return 1;
  }
  if (req.printId && sent.id !== null) process.stdout.write(`${sent.id}\n`);
  return 0;
}
