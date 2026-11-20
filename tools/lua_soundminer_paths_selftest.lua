-- Called by lua_soundminer_import_selftest with a synthetic profile and the
-- same generated runtime, private catalog storage and host API as the app.
return function(prs, fixture, launch, finish, key, read, write, mkdir)
  local database = fixture .. "/SoundminerV7/Databases/Synthetic.sqlite"
  local profile = fixture .. "/SoundminerV7/v7Prefs.xml"
  local relative = "/FX/impact.wav"
  local logical = "/Volumes/SM-Audio" .. relative
  local actual = fixture .. "/audio" .. relative
  local original = read(actual)
  local opened = prs.SoundminerCatalog.open({path=database, waveforms=false})
  local legacy = launch()
  assert(finish(legacy).offline == 6, "start with an unmapped Beta 7 catalog")
  local function find(env) return assert(env.runtime.by_path[env.path_key(logical)]) end
  local asset = find(legacy)
  assert(asset.last_seen == 0 and not legacy.source_file_exists(asset.path))
  asset.notes = "keep my edit"
  legacy.runtime.favorites[legacy.path_key(asset.path)] = true
  legacy.mark_asset_database_change(asset)
  assert(legacy.save_database_now() and legacy.save_config())
  legacy.webview_close()

  -- v7Prefs.xml is the application-owned document. Different versions may
  -- coexist. Include disabled, overlapping, escaped and unrelated rules.
  local function xml_escape(s) return (s:gsub("&", "&amp;"):gsub('"', "&quot;")) end
  local dest = xml_escape(fixture .. "/audio")
  local xml = table.concat({
    '<?xml version="1.0"?><PROPERTIES><extraPrefs><relinkpresets>',
    '<item source="/Volumes/SM-Audio" dest="Q:" state="0"/>',
    '<item state="1" dest="R:/wrong" source="/Volumes/SM-Audio-Other"/>',
    '<item dest="' .. dest .. '" source="/Volumes/SM&#45;Audio" state="1"/>',
    '<item source="/Volumes/SM-Audio" state="1" dest="R:/later"/>',
    '<item source="/Volumes/Unavailable" dest="Q:/missing" state="1"/>',
    '<item source="R:/original" dest="' .. dest .. '" state="true"/>',
    '<item source="/Users/Audio" dest="' .. dest .. '" state="1"/>',
    '<item source="/Volumes/FX &amp; Music" dest="' .. dest .. '" state="1"/>',
    '</relinkpresets></extraPrefs></PROPERTIES>',
  })
  write(profile, xml)
  mkdir(fixture .. "/SoundminerV6")
  local v6 = fixture .. "/SoundminerV6/v6Prefs.xml"
  local other = '<PROPERTIES><relinkpresets><item source="/Volumes/SM-Audio" dest="R:/v6" state="1"/></relinkpresets></PROPERTIES>'
  write(v6, other)
  local count = #prs.SoundminerCatalog.list().catalogs
  prs.SoundminerCatalog.activate(opened.id)
  local mapped = launch()
  mapped.SoundminerCatalog.process_pending()
  assert(not mapped.runtime.import_session and mapped.PsyReaSFXScope.id == opened.id)
  asset = find(mapped)
  assert(asset.notes == "keep my edit" and mapped.runtime.favorites[mapped.path_key(logical)])
  assert(mapped.source_file_exists(asset.path) and mapped.file_size(asset.path) == #original)
  assert(key(mapped.SoundminerPaths.resolve(asset.path)) == key(actual))
  assert(key(mapped.SoundminerPaths.resolve("/Volumes/FX & Music" .. relative)) == key(actual))
  assert(key(mapped.SoundminerPaths.resolve("/Users/Audio" .. relative)) == key(actual))
  assert(key(mapped.WebUI.handlers["soundminer.sourceLocation"]({path=asset.path}).path) == key(actual))
  local source = assert(mapped.SoundminerMedia.open_source(asset.path))
  assert(source:read(12) == original:sub(1, 12) and source:unchanged() and source:close())
  local streamed
  mapped.reaper.PRS_Audio_Open = function(path) streamed = path; return 17 end
  mapped.reaper.PRS_Audio_Close = function() end
  assert(mapped.SoundminerMedia.stream(asset) == 17 and key(streamed) == key(actual))
  local prepared
  assert(mapped.SoundminerMedia.prepare({asset}, function(ok) prepared = ok end))
  for _ = 1, 12 do mapped.SoundminerMedia.process() end
  local copy = assert(mapped.SoundminerMedia.path(asset))
  assert(prepared and key(copy) ~= key(actual) and read(copy) == original, "private media for insertion, drag and transfer")
  assert(mapped.SoundminerCatalog.resume().started)
  local resumed = finish(mapped)
  assert(resumed.added == 0 and #mapped.runtime.assets == 6 and #mapped.runtime.root_records == 1)
  assert(find(mapped) == asset and not mapped.runtime.by_path[mapped.path_key(actual)])
  assert(#prs.SoundminerCatalog.list().catalogs == count and not prs.source_file_exists(logical))
  assert(read(profile) == xml and read(v6) == other and read(actual) == original)

  -- Use synthetic drive inventories so a test never checks the tester's local
  -- or network drives. Compare whole relative paths, even when filenames match.
  local raw = mapped.SoundminerReadOnly.stat
  local candidates = {["q:/one/deep/a.wav"]=true, ["q:/two/b.wav"]=true, ["r:/two/b.wav"]=true,
    ["r:/original/fx/impact.wav"]=true, ["r:/explicit/fx/impact.wav"]=true, ["r:/v6/fx/impact.wav"]=true}
  local probes = 0
  mapped.SoundminerReadOnly.stat = function(path)
    local k = key(path)
    if k:match("^[qr]:/") then
      probes = probes + 1
      if candidates[k] then return {size=12, identity="3", mtime="1", directory=false} end
      return nil, "missing", 2
    end
    return raw(path)
  end
  mapped.reaper.PRS_SM_LocalDrives = function() return "QR" end
  local function resolve(path) return mapped.SoundminerPaths.resolve(path) end
  assert(key(resolve("/Volumes/Portable/one/deep/a.wav")) == "q:/one/deep/a.wav")
  assert(key(resolve("R:/original/FX/impact.wav")) == "r:/original/fx/impact.wav", "available original wins")
  mapped.runtime.language = "zh"
  local ambiguous, reason = resolve("/Volumes/Portable/two/b.wav")
  assert(not ambiguous and reason:find("多个磁盘", 1, true), reason)
  mapped.runtime.language = "en"
  ambiguous, reason = resolve("/Volumes/Portable/two/b.wav")
  assert(not ambiguous and reason:find("multiple drives", 1, true), reason)
  local offline = mapped.runtime.by_path[mapped.path_key("/Volumes/SM-Audio/FX/offline.wav")]
  local ok, failed = pcall(mapped.WebUI.handlers["soundminer.sourceLocation"], {path=offline.path})
  assert(not ok and failed:find("Connect the drive", 1, true), failed)
  assert(mapped.WebUI.handlers["soundminer.sourceLocation"]({path=offline.path, allowOriginal=true}).path == offline.path)
  assert(not resolve("/Volumes/Portable/elsewhere/a.wav"))
  assert(not resolve("/Volumes/Unavailable/one/deep/a.wav"), "missing configured targets never silently switch drives")
  local before = probes
  assert(not resolve("/Volumes/Portable/../one/deep/a.wav") and probes == before, "reject traversal before I/O")
  assert(not resolve("//./pipe/file") and probes == before)
  mapped.PsyReaSFXScope.params.oldPrefix, mapped.PsyReaSFXScope.params.newPrefix = "/Volumes/SM-Audio", "R:/explicit"
  assert(key(resolve(logical)) == "r:/explicit/fx/impact.wav")
  assert(key(resolve("R:/explicit/FX/impact.wav")) == "r:/explicit/fx/impact.wav", "Beta 7 explicit mapped row")
  assert(not resolve("/Volumes/SM-Audio/Music/tone.wav"), "explicit missing destination keeps user choice")
  mapped.PsyReaSFXScope.params.oldPrefix, mapped.PsyReaSFXScope.params.newPrefix = "", ""
  local now = mapped.HostApi.time_precise() + 10
  mapped.HostApi.time_precise = function() return now end
  write(profile, xml:sub(1, -16))
  assert(key(resolve(logical)) == key(actual), "a partial preferences save keeps the last complete rules")
  now = now + 6
  write(profile, '<PROPERTIES><relinkpresets><item source="/Volumes/SM-Audio" dest="R:/explicit" state="1"/></relinkpresets></PROPERTIES>')
  assert(key(resolve(logical)) == "r:/explicit/fx/impact.wav", "pick up complete preference edits without reopening")
  write(profile, xml)
  mapped.PsyReaSFXScope = {kind="soundminer", sourcePath=fixture .. "/SoundminerV6/Databases/Coexisting.sqlite"}
  assert(key(resolve(logical)) == "r:/v6/fx/impact.wav", "use the database's own application profile")
end
