import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const source = await readFile(new URL("../src/web/playback.js", import.meta.url), "utf8");
const { PlaybackClock } = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`);
const clock = new PlaybackClock();
const state = (position, overrides = {}) => ({ position, playing: true, previewPath: "a.wav",
  playback: { epoch: 1, velocity: 0.1, start: 0, end: 1, loop: false }, ...overrides });
const close = (actual, expected) => assert(Math.abs(actual - expected) < 1e-9, `${actual} != ${expected}`);
clock.accept(state(0.1), 1000);
close(clock.position(1016), 0.1016);
close(clock.position(1140), 0.114);
clock.accept(state(0.114), 1150);
close(clock.position(1150), 0.115); // no backwards jump from small host jitter
close(clock.position(1230), 0.122); // correction converges to authoritative anchor
clock.accept(state(0.7, { playback: { epoch: 2, velocity: 0.1, start: 0, end: 1 } }), 1250);
close(clock.position(1250), 0.7); // seek/new preview is immediate
clock.accept(state(0.71, { playing: false }), 1350);
close(clock.position(5000), 0.71);
assert(!clock.active(1350));
clock.accept(state(0.39, { playback: { epoch: 3, velocity: 0.2, start: 0.2, end: 0.4, loop: true } }), 6000);
close(clock.position(6100), 0.21); // selection loop, 2x speed
clock.accept(state(0.21, { playback: { epoch: 4, velocity: -0.2, start: 0.2, end: 0.4, loop: true } }), 7000);
close(clock.position(7100), 0.39); // reverse selection loop
clock.accept(state(0.21, { playback: { epoch: 5, velocity: -0.2, start: 0.2, end: 0.4 } }), 8000);
close(clock.position(8100), 0.2);
assert(!clock.active(8100));
clock.accept(state(0.1), 9000);
close(clock.position(10000), 0.15); // stale host: stop visual prediction after 500 ms
assert(!clock.active(9500));
clock.accept(state(0.1, { playback: { velocity: 0, start: 0, end: 1 } }), 11000);
assert(!clock.active(11000)); // startup seek guard has no guessed movement
console.log("Playback clock passed: frame interpolation, jitter, seek, pause, rate, selection, reverse, loop and stale host");
