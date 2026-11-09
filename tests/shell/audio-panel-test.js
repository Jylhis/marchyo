"use strict";

const assert = require("node:assert/strict");
const A = require("../../shell/Commons/AudioDevices.js");

const stream = (name) => ({ properties: { "application.name": name } });
const spotify = { identity: "Spotify", canPlay: true, isPlaying: true };
const firefox = { identity: "Firefox", canPlay: true, isPlaying: true };

assert.equal(A.deviceGlyph({ name: "USB headphones" }, false), "󰋋");
assert.equal(A.deviceGlyph({ name: "Speakers" }, false), "󰓃");
assert.equal(A.deviceGlyph({ name: "Microphone" }, true), "󰍬");
assert.equal(A.deviceGlyph(null, true), "󰍬");
assert.equal(A.streamLabel(stream("spotify"), [spotify], []), "Spotify");
assert.equal(A.streamLabel(stream("audio-src"), [spotify], []), "Spotify");
assert.equal(A.streamLabel(stream("audio-src"), [spotify, firefox], []), "audio-src");
assert.equal(
  A.streamLabel(stream("audio-src"), [spotify, firefox], [stream("spotify")]),
  "Firefox",
);
assert.equal(
  A.streamLabel(
    stream("audio-src"),
    [{ ...spotify, dbusName: "org.mpris.MediaPlayer2.playerctld" }],
    [],
  ),
  "audio-src",
);
assert.equal(A.streamLabel(stream("Recorder"), [spotify], []), "Recorder");
assert.equal(A.streamLabel(null, [], []), "");
console.log("audio panel tests passed");
