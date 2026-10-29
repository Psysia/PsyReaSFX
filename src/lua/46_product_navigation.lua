-- Resolve a publisher's product folder, rather than a logical imported library.
-- Only the selected asset and a bounded ancestor chain are considered. All I/O
-- is supplied by the runtime; no catalog walks, audio analysis or DB mutations.
ProductNavigation = { max_parents = 6, artwork_max_bytes = 2 * 1024 * 1024,
  metadata_cache = {}, metadata_order = {}, metadata_cache_limit = 256 }

local function normalized(value)
  return tostring(value or ""):gsub("([a-z])([A-Z])", "%1 %2"):lower()
    :gsub("[%c%p]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function compact_name(value) return normalized(value):gsub("%s", "") end

local generic = {}
for word in ("audio wav wave waves wavs aiff flac mp3 stereo mono multichannel "
  .. "samples sounds sound sfx effects assets library libraries collections packs "
  .. "artwork art cover covers images pictures documentation docs manuals "
  .. "ambience ambiences ambient backgrounds loops oneshots hits impacts whooshes "
  .. "weapons footsteps foley vehicles water fire explosions ui games music "
  .. "short long small large dry wet processed unprocessed raw edited") :gmatch("%S+") do
  generic[word] = true
end
for _, word in ipairs({"sound effects", "sound effect library", "sound libraries", "sample library",
  "sound packs", "audio files", "one shots", "sound effect libraries", "音效", "音效库", "素材库",
  "音频", "封面", "图片", "文档", "脚步", "武器", "环境", "音效素材"}) do
  generic[compact_name(word)] = true
end

local vendors = { "boom library", "ghosthack", "artlist", "cinetools", "lens distortions",
  "pro sound effects", "soundmorph", "sound ideas", "sonniss", "epic stock media",
  "soundly", "hiss and a roar", "hiss and roar", "asoundeffect" }

local umbrella = { all=true, complete=true, collection=true, collections=true,
  alllibraries=true, allproducts=true, allpacks=true, completecollection=true,
  ultimatecollection=true, fullcollection=true, bundle=true, fullbundle=true,
  completebundle=true, archive=true, ["合集"]=true, ["全集"]=true, ["全部音效库"]=true }

local function product_title(value)
  local name = compact_name(value)
  for _, vendor in ipairs(vendors) do
    local prefix = compact_name(vendor)
    if name:sub(1,#prefix) == prefix then return name:sub(#prefix+1) end
  end
  -- BOOM is also commonly used without the word "Library".
  if name:sub(1,4) == "boom" then return name:sub(5) end
  return name
end

local structural = { audio=true, wav=true, wavs=true, waves=true, stereo=true, mono=true,
  artwork=true, art=true, cover=true, covers=true, images=true, pictures=true,
  documentation=true, docs=true, manuals=true, ["音频"]=true, ["封面"]=true, ["图片"]=true, ["文档"]=true }

local function role_name(value)
  return compact_name(value):gsub("^%d+", "")
end

local function is_generic(value)
  local name = role_name(value)
  if name == "" or generic[name] or name:match("^%d+$")
    or name:match("^%d+k?hz") or name:match("^%d+bit")
    or name:match("^vol[ume]*%d+$") then return true end
  if name:find("soundeffectlibrary", 1, true) == 1
    or name:find("soundeffectlibraries", 1, true) == 1 then return true end
  for _, vendor in ipairs(vendors) do
    if name == compact_name(vendor) then return true end
  end
  local title = product_title(value)
  if title == "" or (title ~= compact_name(value) and umbrella[title]) then return true end
  if title ~= compact_name(value) then
    local rest = title:gsub("soundeffects", ""):gsub("sounds", ""):gsub("sound", "")
    if rest == "" or umbrella[rest] or rest:match("^%d+$") then return true end
  end
  return false
end

local filler = { sound=true, sounds=true, sfx=true, library=true, libraries=true,
  pack=true, packs=true, bundle=true, collection=true, collections=true,
  audio=true, wav=true, volume=true, vol=true, edition=true }

local function words(value)
  local out = {}
  for word in normalized(value):gmatch("%S+") do
    if not filler[word] and not word:match("^%d+$") then out[#out+1] = word end
  end
  return out
end

local function matches_product_name(folder, name)
  if is_generic(folder) or is_generic(name) then return false end
  local a, b = product_title(folder), product_title(name)
  if a == b and #a >= 4 then return true end
  local wanted, supplied = words(folder), {}
  for _, word in ipairs(words(name)) do supplied[word] = true end
  if #wanted < 2 then return false end
  for _, word in ipairs(wanted) do if not supplied[word] then return false end end
  return true
end

local function naming_score(folder, filename)
  if is_generic(folder) then return 0 end
  local name, meaningful = normalized(folder), words(folder)
  local compact = compact_name(folder)
  local vendor_match = name:match("^boom%s") ~= nil
  for _, vendor in ipairs(vendors) do
    if compact:find(compact_name(vendor), 1, true) then vendor_match = true break end
  end
  local cue = vendor_match or name:match("%f[%a]sfx%f[%A]")
    or name:match("%f[%a]sounds?%f[%A]") or name:match("%f[%a]pack%f[%A]")
    or name:match("%f[%a]bundle%f[%A]") or name:find("音效", 1, true)
    or name:find("套装", 1, true)
  if cue and #meaningful >= 2 then return 50 end
  -- A product title carried by the filename is useful even without a known
  -- vendor. Generic categories such as Footsteps/WAV have already been excluded.
  if #meaningful >= 2 and matches_product_name(folder, filename) then return 40 end
  return 0
end

function product_navigation_metadata_names(map)
  local fields = { productname=1, product=1, libraryname=2, library=2, soundlibrary=2,
    album=3, talb=3, iprd=3, pack=4, soundbank=4, collection=5 }
  local entries = {}
  for key, value in pairs(map or {}) do
    local field = compact_name(tostring(key):match("([^:]+)$") or key)
    local rank = fields[field]
    value = tostring(value or "")
    if rank and value ~= "" and #value <= 256 and not value:find("%c") then
      entries[#entries+1] = { rank=rank, key=tostring(key), value=value }
    end
  end
  table.sort(entries, function(a,b) return a.rank < b.rank or (a.rank == b.rank and a.key < b.key) end)
  local names = {}
  for _, entry in ipairs(entries) do names[#names+1] = entry.value end
  return names
end

function product_navigation_remember_metadata(asset, fingerprint, names)
  local cache, order = ProductNavigation.metadata_cache, ProductNavigation.metadata_order
  if not cache[asset] then order[#order+1] = asset end
  cache[asset] = { fingerprint=fingerprint, names=names }
  while #order > ProductNavigation.metadata_cache_limit do cache[table.remove(order,1)] = nil end
end

function resolve_asset_product_folder(asset, hints)
  hints = hints or {}
  local folder = tostring(asset and asset.folder or "")
  if folder == "" then folder = dirname(asset and asset.path or "") end
  if folder == "" then return nil, "missing_folder" end
  local candidates, current = {}, folder
  for depth=0,ProductNavigation.max_parents do
    if current == "" or not path_is_inside(asset.path, current) then break end
    candidates[#candidates+1] = current
    if current:match("^[/\\][/\\][^/\\]+[/\\][^/\\]+$") then break end
    local parent = dirname(current)
    if parent == current or parent == "" or parent:match("^%a:$") then break end
    current = parent
  end

  local best, best_score, reason = folder, 0, "folder"
  -- Prefer an exact full product title before containment matches such as a
  -- parent "Urban Streets" above a category "Urban Streets Interior".
  for pass=1,2 do
    for _, candidate in ipairs(candidates) do
      local name = basename(candidate)
      for _, product in ipairs(hints.metadata_names or {}) do
        local exact = product_title(name) == product_title(product)
        if (pass == 2 or exact) and matches_product_name(name, product) then
          return candidate, "metadata"
        end
      end
    end
  end
  for _, candidate in ipairs(candidates) do
    local name = basename(candidate)
    local score = naming_score(name, asset.name or basename(asset.path))
    if score > best_score then best, best_score, reason = candidate, score, "name" end
  end

  local cover = tostring(hints.cover_path or "")
  if cover == "" or cover == "-" then return best, reason end
  local named_boundary = reason == "name" and best or nil
  local owner = dirname(cover)
  -- Covers often live in "2. Artwork" beside "1. Audio". Structural folders
  -- are skipped, but sound categories and arbitrary siblings are not merged.
  for _=1,3 do
    if not structural[role_name(basename(owner))] then break end
    local parent = dirname(owner)
    if parent == owner or parent == "" then break end
    owner = parent
  end
  for _, candidate in ipairs(candidates) do
    if named_boundary and not path_is_inside(candidate, named_boundary) then break end
    local name = basename(candidate)
    local ambiguous_root = hints.root and path_key(candidate) == path_key(hints.root)
      and naming_score(name, asset.name or basename(asset.path)) == 0
    if not is_generic(name) and not ambiguous_root then
      local name_score = naming_score(name, asset.name or basename(asset.path))
      local same = path_key(candidate) == path_key(owner)
        or (name_score > 0 and path_is_inside(owner, candidate))
      if not same and hints.cover_at and hints.same_artwork then
        local other = hints.cover_at(candidate)
        same = other and other ~= "" and hints.same_artwork(cover, other)
      end
      local score = 80 + name_score
      if same and (score > best_score or (score == 80 and best_score == 80)) then
        best, best_score, reason = candidate, score, "cover"
      end
    end
  end
  return best, reason
end
