local catalog_path = assert(
  arg[1],
  "usage: lua_ucs_catalog_selftest.lua <ucs-catalog.tsv> <ucs-module.lua>"
)
local module_path = assert(arg[2])
local scale = tonumber(arg[3]) or 500000

function trim(value)
  return tostring(value or ""):match("^%s*(.-)%s*$")
end

function unescape_tsv(value)
  return (value or ""):gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

function split_tsv(line)
  local fields = {}
  for field in (line .. "\t"):gmatch("(.-)\t") do
    fields[#fields + 1] = unescape_tsv(field)
  end
  return fields
end

function basename(path)
  return tostring(path or ""):match("([^/\\]+)$") or tostring(path or "")
end

function strip_extension(name)
  return tostring(name or ""):gsub("%.[^%.]+$", "")
end

UCS_CATALOG_PATH = catalog_path
dofile(module_path)

local loaded, count = load_ucs_catalog(catalog_path)
assert(loaded and count == 753, "official UCS catalog did not load")
assert(#UcsCatalog.entries == 753)

local category_count = 0
for _ in pairs(UcsCatalog.categories) do category_count = category_count + 1 end
assert(category_count == 82, "unexpected UCS category count")

local wood = assert(UcsCatalog.by_catid.WOODHndl)
assert(wood.category == "WOOD" and wood.subcategory == "HANDLE")
assert(wood.category_zh ~= "" and wood.subcategory_zh ~= "")

local filename = assert(
  ucs_classify_filename_exact("AIRBrst_Pressure Release 01.wav")
)
assert(filename.catid == "AIRBrst")
assert(filename.category == "AIR" and filename.subcategory == "BURST")
assert(filename.ucs_source == "filename" and filename.ucs_confidence == 1)

assert(
  ucs_classify_filename_exact("airbrst_Pressure Release.wav") == nil,
  "CatID filename matching must remain case-sensitive"
)
assert(
  ucs_classify_filename_exact("AIRBrstExtra.wav") == nil,
  "CatID matching accepted a prefix without a delimiter"
)

local metadata = assert(ucs_classify_metadata("", "air", "burst"))
assert(metadata.catid == "AIRBrst" and metadata.ucs_source == "metadata")
assert(ucs_classify_metadata("NOTREAL", "", "") == nil)

local metadata_fields = {
  ["IXML:USER:SUBCATEGORY"] = "BURST",
  ["IXML:USER:CATEGORY"] = "AIR",
  ["IXML:USER:CATID"] = "AIRBrst",
}
assert(ucs_metadata_pick(metadata_fields, { "CATEGORY" }) == "AIR")
assert(ucs_metadata_pick(metadata_fields, { "SUBCATEGORY" }) == "BURST")
assert(ucs_metadata_pick(metadata_fields, { "CATID" }) == "AIRBrst")

local started = os.clock()
for index = 1, scale do
  local test_name = index % 2 == 0
    and "AIRBrst_Performance Test.wav"
    or "WOODHndl_Performance Test.wav"
  assert(ucs_classify_filename_exact(test_name))
end
local elapsed = os.clock() - started

print(string.format(
  "Lua UCS catalog self-test OK: records=753 categories=82 lookups=%d elapsed=%.3fs",
  scale,
  elapsed
))
