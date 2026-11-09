-- Differential test: the compiled search/view predicates used by the results
-- rebuild must accept exactly the assets the previous per-asset implementation
-- (reproduced below) accepted, and parse the query once instead of per asset.
local runtime_path = assert(arg[1], "runtime UI module is required")
local core_path = assert(arg[2], "UI core module is required")
local catalog_path = assert(arg[3], "catalog module is required")

local function read(path)
  local handle = assert(io.open(path, "rb"))
  local text = handle:read("*a")
  handle:close()
  return text
end
local function region(source, first, following)
  local at = assert(source:find(first, 1, true), first)
  local last = assert(source:find(following, at + #first, true), following)
  return source:sub(at, last - 1)
end

local core, catalog, runtime = read(core_path), read(catalog_path), read(runtime_path)

SEP = "/"
function path_key(path) return (tostring(path or ""):gsub("\\", "/"):lower()) end
function workflow_label(status) return "wf-" .. tostring(status) end
function asset_is_played(asset) return asset.played == true end
function ucs_asset_hierarchy(asset)
  return trim(asset.category or ""), trim(asset.subcategory or ""), trim(asset.catid or "")
end
function project_usage_bucket(project_path, create)
  return state.project_usage[path_key(project_path or "")]
end

assert(load(region(core, "function trim(value)", "function rgba_from_hex(hex)")))()
assert(load(region(core, "function safe_lower(value)", "function windows_extended_path(path)")))()
assert(load(region(core, "function split_words(text)", "function fnv1a(text)")))()
assert(load(region(core, "function path_is_inside(path, root)", "function invalidate_folder_navigation()")))()
assert(load(region(catalog, "function asset_path_sort_key(asset)", "function invalidate_ucs_counts()")))()
assert(load(region(runtime, "function ucs_directory_view(view)", "function ucs_category_display_name(")))()
assert(load(region(runtime, "function search_blob(asset)", "local function cached_sort_text(")))()
assert(load(region(runtime, "function results_filter_predicate()", "function start_results_rebuild()")))()

-- Reference: the per-asset implementation that preceded the compiled one.
local function reference_matches_search(asset)
  if "ai_semantic" == state.view then return true end
  local query = trim(state.search)
  if query == "" then return true end
  local blob = search_blob(asset)
  for _, raw in ipairs(split_words(query)) do
    local exclude = raw:sub(1, 1) == "-"
    local token = exclude and raw:sub(2) or raw
    token = safe_lower(token)
    if token ~= "" then
      local field, wanted = token:match("^([%w_]+)%:(.+)$")
      local matched
      if field then
        matched = safe_lower(field_value(asset, field)):find(wanted, 1, true) ~= nil
      else
        matched = blob:find(token, 1, true) ~= nil
      end
      if exclude and matched then return false
      elseif not exclude and not matched then return false end
    end
  end
  return true
end

local function reference_asset_in_view(asset)
  if not asset.ready or asset.pending_batch then return false end
  local ucs_category, ucs_subcategory, ucs_catid
  if ucs_directory_view(state.view) then
    ucs_category, ucs_subcategory, ucs_catid = ucs_asset_hierarchy(asset)
  end
  local key = path_key(asset.path)
  if state.view == "favorites" and not state.favorites[key] then return false
  elseif state.view == "recent" and (asset.last_used or 0) <= 0 then return false
  elseif state.view == "previewed" and (asset.last_previewed or 0) <= 0 then return false
  elseif "ucs_pending" == state.view and asset.ucs_status ~= "pending" then return false
  elseif "ucs_category" == state.view and ucs_category ~= state.ucs_filter_category then return false
  elseif "ucs_subcategory" == state.view
    and (ucs_category ~= state.ucs_filter_category
      or ucs_subcategory ~= state.ucs_filter_subcategory) then return false
  elseif "ucs_catid" == state.view and ucs_catid ~= state.ucs_filter_catid then return false
  elseif "similar" == state.view and not state.similarity_lookup[key] then return false
  elseif "ai_semantic" == state.view and not state.ai_semantic_lookup[key] then return false
  elseif state.view == "missing" and not state.missing_assets[key] then return false
  elseif state.view == "duplicates" and not state.duplicate_lookup[key] then return false
  elseif state.view == "duplicates_confirmed" and not state.duplicate_confirmed_lookup[key] then return false
  elseif state.view == "duplicate_failures" and not state.duplicate_confirmation_failures[key] then return false
  elseif state.view == "project_used" then
    local bucket = project_usage_bucket(state.current_project_path, false)
    if not bucket or not bucket.assets[key] then return false end
  end
  if state.active_collection_id then
    local collection = state.collection_by_id[state.active_collection_id]
    if not collection or not collection.items[key] then return false end
  end
  if state.status_filter and (asset.workflow_status or "none") ~= state.status_filter then
    return false
  end
  if state.root_filter and not path_is_inside(asset.path, state.root_filter) then
    return false
  end
  if state.library_filter_id and asset.library_id ~= state.library_filter_id then
    return false
  end
  return true
end

-- Deterministic corpus.
local seed = 424242
local function random_below(limit)
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % limit + 1
end
local function pick(list) return list[random_below(#list)] end

local names = { "Door Creak", "Wood Door Slam", "Impact Heavy", "Footstep Gravel", "Ambience Forest", "WHOOSH fast", "Glass Break", "Metal Hit" }
local categories = { "IMPACT", "DOORS", "FOOTSTEPS", "", "AMBIENCE" }
local subcategories = { "WOOD", "METAL", "", "GRAVEL" }
local catids = { "IMPTWood", "DOORWood", "FOOTGrav", "", "AMBFrst" }
local statuses = { "none", "candidate", "approved", "rejected" }
local libraries = { "Alpha", "Beta", "Gamma" }
local roots = { "C:/Lib/A", "C:/Lib/B", "D:/Other" }

local state_assets = {}
local favorites, missing, duplicates, confirmed, failures = {}, {}, {}, {}, {}
local similar, ai, project_assets, collection_items = {}, {}, {}, {}
for index = 1, 300 do
  local root = pick(roots)
  local asset = {
    name = pick(names) .. " " .. index,
    path = root .. "/sub" .. random_below(4) .. "/File" .. index .. ".wav",
    library = pick(libraries),
    library_id = "lib" .. random_below(3),
    description = pick({ "creak and slam", "heavy hit", "", "Forest wind" }),
    keywords = pick({ "door, wood", "impact", "", "ambience, birds" }),
    category = pick(categories),
    subcategory = pick(subcategories),
    catid = pick(catids),
    channels = random_below(2),
    workflow_status = pick(statuses),
    marked = random_below(5) == 1,
    played = random_below(4) == 1,
    ready = random_below(12) ~= 1,
    pending_batch = random_below(15) == 1 or nil,
    last_used = random_below(3) - 1,
    last_previewed = random_below(3) - 1,
    ucs_status = pick({ "pending", "exact", "manual", "unclassified" }),
  }
  state_assets[index] = asset
  local key = path_key(asset.path)
  if random_below(4) == 1 then favorites[key] = true end
  if random_below(6) == 1 then missing[key] = true end
  if random_below(5) == 1 then duplicates[key] = "grp" end
  if random_below(7) == 1 then confirmed[key] = "grp" end
  if random_below(9) == 1 then failures[key] = true end
  if random_below(4) == 1 then similar[key] = { score = 1 } end
  if random_below(4) == 1 then ai[key] = { page = 1 } end
  if random_below(3) == 1 then project_assets[key] = true end
  if random_below(2) == 1 then collection_items[key] = true end
end

state = {
  assets = state_assets,
  search = "",
  view = "all",
  favorites = favorites,
  missing_assets = missing,
  duplicate_lookup = duplicates,
  duplicate_confirmed_lookup = confirmed,
  duplicate_confirmation_failures = failures,
  similarity_lookup = similar,
  ai_semantic_lookup = ai,
  project_usage = { [path_key("C:/Proj/a.rpp")] = { assets = project_assets } },
  current_project_path = "C:/Proj/a.rpp",
  collection_by_id = { present = { items = collection_items } },
  root_by_id = {},
  ucs_filter_category = "DOORS",
  ucs_filter_subcategory = "WOOD",
  ucs_filter_catid = "DOORWood",
}

local queries = {
  "", "   ", "-", "- ", "door", "Door", "DOOR  wood", "door -wood", "-door",
  "'wood door'", "\"heavy hit\"", "cat:impact", "category:impact -catid:imptwood",
  "fav:true", "fav:false", "marked:true", "missing:false", "dupe:true",
  "duplicate:false", "ch:2", "channels:1", "status:approved", "workflow:none",
  "desc:creak", "key:ambience", "unknown:foo", "-name:a", "Path:/lib/a", "name:",
  "played:true", "project:true", "used:false", "root:c:/lib", "lib:alpha",
  "wf-approved", "marked", "snd:x:y",
}
local views = {
  "all", "favorites", "recent", "previewed", "ucs_pending", "ucs_category",
  "ucs_subcategory", "ucs_catid", "similar", "ai_semantic", "missing",
  "duplicates", "duplicates_confirmed", "duplicate_failures", "project_used",
}
local filters = {
  {},
  { active_collection_id = "present" },
  { active_collection_id = "absent" },
  { status_filter = "approved" },
  { root_filter = "C:/Lib/A" },
  { root_filter = "c:\\lib\\b\\" },
  { root_filter = "C:/Lib/A/sub1" },
  { library_filter_id = "lib2" },
  { active_collection_id = "present", status_filter = "candidate", root_filter = "C:/Lib", library_filter_id = "lib1" },
}

local checked = 0
for _, view in ipairs(views) do
  for _, filter in ipairs(filters) do
    for _, query in ipairs(queries) do
      state.view = view
      state.search = query
      state.active_collection_id = filter.active_collection_id
      state.status_filter = filter.status_filter
      state.root_filter = filter.root_filter
      state.library_filter_id = filter.library_filter_id
      -- Drop per-asset caches so both implementations start from equal state.
      for _, asset in ipairs(state_assets) do asset._search_blob = nil end

      local predicate = results_filter_predicate()
      for _, asset in ipairs(state_assets) do
        local expected = reference_asset_in_view(asset) and reference_matches_search(asset)
        local actual = predicate(asset)
        assert(actual == expected, string.format(
          "predicate mismatch view=%s query=%q filter=%d asset=%s expected=%s actual=%s",
          view, query, _, asset.name, tostring(expected), tostring(actual)))
        assert(asset_in_view(asset) == reference_asset_in_view(asset),
          "asset_in_view wrapper must equal the reference")
        assert(matches_search(asset) == reference_matches_search(asset),
          "matches_search wrapper must equal the reference")
        checked = checked + 1
      end
    end
  end
end

-- The query is parsed once per distinct query string, not once per asset.
do
  state.view = "all"
  state.search = "door -wood cat:impact"
  state.active_collection_id, state.status_filter = nil, nil
  state.root_filter, state.library_filter_id = nil, nil
  local first = compile_search_terms(state.search)
  for _ = 1, 50 do
    assert(compile_search_terms(state.search) == first, "terms must be memoised per query")
  end
  state.search = "door"
  assert(compile_search_terms(state.search) ~= first, "a different query must recompile")
  assert(make_search_predicate() ~= nil)
  state.search = "  "
  assert(make_search_predicate() == nil, "an empty query must not add a per-asset filter")
  state.view = "ai_semantic"
  state.search = "door"
  assert(make_search_predicate() == nil, "AI results must not use the literal filter")
end

print(string.format("Lua search/view predicate self-test passed: %d comparisons", checked))
