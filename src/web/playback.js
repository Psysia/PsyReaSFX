// Host positions remain authoritative. Only the visual cursor is extrapolated
// between 150 ms snapshots; no audio scheduling or host RPC runs per frame.
export class PlaybackClock {
  constructor() {
    this.anchor = null;
    this.staleAfter = 500;
  }

  accept(state, now) {
    const timing = state.playback || {};
    const previous = this.anchor;
    const position = Number.isFinite(state.position) ? state.position : 0;
    const velocity =
      state.playing && Number.isFinite(timing.velocity) ? timing.velocity : 0;
    const start = Number.isFinite(timing.start) ? timing.start : 0;
    const end = Number.isFinite(timing.end) ? timing.end : 1;
    const key = [
      state.previewPath,
      timing.epoch,
      start,
      end,
      velocity,
      timing.loop,
    ].join("|");
    const predicted = this.position(now);
    // Small timing jitter is corrected over a few display frames. A new
    // source, seek, rate, direction or selection jumps to the exact host anchor.
    const correction =
      previous?.key === key &&
      velocity &&
      now - previous.at < this.staleAfter &&
      Math.abs(predicted - position) <= Math.abs(velocity) * 0.12
        ? predicted - position
        : 0;
    this.anchor = {
      key,
      position,
      velocity,
      start,
      end,
      at: now,
      loop: state.playing && timing.loop === true,
      correction,
    };
  }

  position(now) {
    const a = this.anchor;
    if (!a) return 0;
    const elapsed = Math.max(0, Math.min(this.staleAfter, now - a.at));
    let value =
      a.position +
      (a.velocity * elapsed) / 1000 +
      a.correction * Math.max(0, 1 - elapsed / 80);
    const span = a.end - a.start;
    if (a.loop && span > 0 && (value < a.start || value > a.end))
      value = a.start + ((((value - a.start) % span) + span) % span);
    return Math.max(a.start, Math.min(a.end, value));
  }

  active(now) {
    const a = this.anchor;
    if (!a?.velocity || now - a.at >= this.staleAfter) return false;
    const p = this.position(now);
    return a.loop || (a.velocity > 0 ? p < a.end : p > a.start);
  }
}
