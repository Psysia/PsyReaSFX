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
- Horizontal and vertical scrollbar thumbs track the pointer immediately and
  keep their correct orientation; opening a menu or collection never exposes a
  default white system template.
- The currently auditioned list waveform shows a cyan mini playhead.
- Selected, played and ordinary rows keep the Lua color hierarchy.
- Waveform-state color priority is selected, marked, played, then normal.
- Scrollbar rails stay visible for the full viewport. Thumb size represents the
  viewport proportion and both orientations must respond to direct pointer
  drag. The thumb is centered inside its rail and no edge may be clipped into a
  half-pill.

## Preview console

- Multichannel waveforms use independent lanes and visible L/R or CH labels.
- Click seeks; drag creates a selection; wheel zooms; Shift+wheel pans; double
  click resets the view.
- A valid selection shows one compact drag capsule inside the waveform. Dragging
  it exports precisely that range as a temporary file for a standard Windows
  file drop; creating the selection alone must never start a file drag.
- Named saved Regions are recalled from the preview strip without opening a
  separate window or stealing Space/transport shortcuts.
- Current/In/Out/Duration/Zoom remain on one compact information strip.
- Transport, Rate, Gain and audition modes remain available when either side
  panel is open.
- A control is visible only when it performs the real operation.

## Settings and localization

- English/Chinese switching covers the full named navigation structure and may
  be repeated without restarting or invalidating WPF inline collections.
- Dark and Classic presets are available. Framework, accent, played text,
  waveform states, selection and playhead are editable through a color picker.
- Appearance changes preview live; Cancel restores the incoming palette and
  Save persists it.
- Space behavior is explicit: pause/resume or restart from selection start.

## Performance budget

- Window chrome is displayed before catalog work begins.
- Wheel scrolling does not start waveform decoding for transient recycled rows.
- Selection changes do not synchronously decode Artwork or detailed waveforms.
- Only the currently auditioned row receives bounded 30–60 Hz playhead notifications.
- Large-library scanning, Artwork and waveform jobs yield to user interaction.
