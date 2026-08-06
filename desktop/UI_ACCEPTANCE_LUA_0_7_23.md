# Desktop UI acceptance contract — Lua 0.7.23 Stable

The Lua Stable interface is the visual and interaction baseline for Desktop.
Desktop is not considered visually migrated because it uses the same colors;
the information hierarchy, density, responsive behavior and interaction states
must also match.

## Shell

- Compact one-row brand/search/command bar with borderless icon controls.
- Navigation toggle remains beside the wordmark; inspector toggle remains at
  the far right.
- The pinned breadcrumb/sort strip stays visible above results.
- Focus mode hides both side panels without changing the central workflow.
- Side panels and the preview area remain resizable and never cover controls.

## Navigation and results

- Navigation sections are collapsible. Only working sections are shown.
- Default results columns are Waveform, Filename, Keywords / Description,
  Artwork and Duration. Optional metadata fields are selected from the pinned
  header context menu.
- Scrolling uses recycling virtualization and must not synchronously decode
  thumbnails, Artwork or metadata.
- The currently auditioned list waveform shows a cyan mini playhead.
- Selected, played and ordinary rows keep the Lua color hierarchy.

## Preview console

- Multichannel waveforms use independent lanes and visible L/R or CH labels.
- Click seeks; drag creates a selection; wheel zooms; Shift+wheel pans; double
  click resets the view.
- Current/In/Out/Duration/Zoom remain on one compact information strip.
- Transport, Rate, Gain and audition modes remain available when either side
  panel is open.
- A control is visible only when it performs the real operation.

## Performance budget

- Window chrome is displayed before catalog work begins.
- Wheel scrolling does not start waveform decoding for transient recycled rows.
- Selection changes do not synchronously decode Artwork or detailed waveforms.
- Only the currently auditioned row receives bounded 30–60 Hz playhead notifications.
- Large-library scanning, Artwork and waveform jobs yield to user interaction.
