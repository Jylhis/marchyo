"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const B = require("../../shell/Commons/Bluetooth.js");

for (const name of [
  "",
  "AA:BB:CC:DD:EE:FF",
  "AA-BB-CC-DD-EE-FF",
  "12345678-abcd-1234-aaaa-123456789abc",
  "12345678abcd1234aaaa123456789abc",
  "0x180f",
])
  assert.equal(B.hasHumanName(name), false, name);
assert.equal(B.hasHumanName("Living room speaker"), true);
const rows = [
  { name: "Mouse", paired: true },
  { name: "AA:BB:CC:DD:EE:FF" },
  { name: "Speaker", connected: true },
  { name: "Buds" },
  { name: "AA:BB:CC:DD:EE:00", paired: true },
];
assert.deepEqual(
  B.sections(rows, false).map((g) => g.key),
  ["connected", "paired"],
);
const groups = B.sections(rows, true);
assert.deepEqual(
  groups.map((g) => g.key),
  ["connected", "paired", "available"],
);
assert.deepEqual(
  groups[2].rows.map((r) => r.name),
  ["Buds"],
);
assert.equal(groups[1].rows.length, 2);
const device = { name: "Speaker", address: "AA:BB:CC:DD:EE:FF" };
const sink = { isSink: true, name: "bluez_output.AA_BB_CC_DD_EE_FF.1" };
assert.equal(B.sinkMatchesDevice(sink, device), true);
assert.equal(
  B.sinkMatchesDevice(
    { isSink: true, name: "Headphones", properties: { "api.bluez5.address": device.address } },
    device,
  ),
  true,
);
assert.equal(B.sinkMatchesDevice({ ...sink, isStream: true }, device), false);
assert.equal(B.sinkMatchesDevice({ isSink: true, name: "Speaker" }, device), false);
assert.equal(
  B.sinkMatchesDevice({ ...sink, name: "bluez_output.AA_BB_CC_DD_EE_00" }, device),
  false,
);

const source = fs.readFileSync(
  path.join(__dirname, "../../shell/Services/BluetoothState.qml"),
  "utf8",
);
function service() {
  const adapter = { enabled: true, discovering: false };
  const root = {
    adapter,
    available: true,
    enabled: true,
    pendingActions: {},
    audioRoutes: {},
    openPanels: 0,
    ownsScan: false,
    scanAdapter: null,
  };
  Object.defineProperty(root, "scanning", { get: () => adapter.discovering });
  const context = vm.createContext({
    root,
    BT: B,
    Date,
    Object,
    JSON,
    Bluetooth: { devices: { values: [] } },
    Pipewire: { nodes: { values: [] } },
  });
  const methods = source.matchAll(/^    function (\w+)\((.*?)\)(?:: \w+)? \{([\s\S]*?)^    }/gm);
  for (const [, name, args, body] of methods) {
    const parameters = args.replace(/: \w+/g, "");
    root[name] = vm.runInContext(`(function(${parameters}) {${body}})`, context);
  }
  return { root, adapter, context };
}

{
  const { root, adapter } = service();
  root.acquireScan();
  assert.equal(adapter.discovering, true);
  assert.equal(root.ownsScan, true);
  root.acquireScan();
  root.releaseScan();
  assert.equal(adapter.discovering, true);
  root.releaseScan();
  assert.equal(adapter.discovering, false);
}
{
  const { root, adapter } = service();
  adapter.discovering = true;
  root.acquireScan();
  root.releaseScan();
  assert.equal(adapter.discovering, true, "keep another application's scan running");
}
{
  const { root, adapter, context } = service();
  let connects = 0;
  let pairs = 0;
  const d = {
    ...device,
    adapter,
    paired: false,
    connected: false,
    pair: () => pairs++,
    connect: () => connects++,
  };
  context.Bluetooth.devices.values = [d];
  root.activate({ address: d.address });
  assert.equal(pairs, 1);
  root.activate({ address: d.address });
  assert.equal(pairs, 1, "a stale row cannot submit the same action twice");
  const pending = root.pendingActions;
  root.settleActions();
  assert.equal(root.pendingActions, pending, "waiting must preserve delegate membership");
  d.paired = true;
  root.settleActions();
  assert.equal(connects, 1);
  assert.equal(root.pendingActions[d.address].action, "connect");
  d.connected = true;
  root.settleActions();
  assert.equal(Object.keys(root.pendingActions).length, 0);
  context.Pipewire.nodes.values = [sink];
  root.routeAudio();
  assert.equal(context.Pipewire.preferredDefaultAudioSink, sink);
  assert.equal(Object.keys(root.audioRoutes).length, 0);
  root.pendingActions[d.address] = { action: "connect", expires: 0 };
  root.settleActions();
  assert.equal(Object.keys(root.pendingActions).length, 0, "a failed action expires");
  root.audioRoutes[d.address] = { ...device, tries: 0 };
  context.Pipewire.nodes.values = [];
  for (let i = 0; i < 8; i++) root.routeAudio();
  assert.equal(Object.keys(root.audioRoutes).length, 0, "sink lookup stops after eight tries");
  d.forget = () => {
    d.paired = false;
  };
  root.forget({ address: d.address, paired: true });
  root.settleActions();
  assert.equal(Object.keys(root.pendingActions).length, 0);
}
console.log("bluetooth panel tests passed");
