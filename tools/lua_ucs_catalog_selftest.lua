local catalog_path = assert(
  arg[1],
  "usage: lua_ucs_catalog_selftest.lua <ucs-catalog.tsv> <ucs-module.lua>"
)
local module_path = assert(arg[2])
local scale = tonumber(arg[3]) or 500000
local keyword_scale = tonumber(arg[4]) or 100000

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

local source_file = assert(io.open(catalog_path, "rb"))
local source_content = source_file:read("*a")
source_file:close()
source_content = source_content:gsub("\r\n", "\n"):gsub("\r", "\n")
local crlf_path = os.tmpname()
local crlf_file = assert(io.open(crlf_path, "wb"))
crlf_file:write((source_content:gsub("\n", "\r\n")))
crlf_file:close()
local crlf_loaded, crlf_count = load_ucs_catalog(crlf_path)
assert(
  crlf_loaded and crlf_count == 753,
  "official UCS catalog must load after a Windows CRLF checkout: "
    .. tostring(crlf_count or UcsCatalog.error)
    .. " path="
    .. crlf_path
)
os.remove(crlf_path)
assert(load_ucs_catalog(catalog_path))

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

local automatic = assert(
  ucs_classify_filename_keywords("AIR Burst Pressure Release 01.wav")
)
assert(automatic.ucs_status == "auto" and automatic.catid == "AIRBrst")
assert(automatic.ucs_source == "filename_keywords")

local ambiguous = assert(ucs_classify_filename_keywords("Burst 01.wav"))
assert(ambiguous.ucs_status == "pending" and ambiguous.catid == "")
assert(ambiguous.ucs_candidates:find("AIRBrst", 1, true))
assert(ambiguous.ucs_candidates:find("FIREBrst", 1, true))

local repeated = assert(
  ucs_classify_filename_keywords("AIR AIR AIR Burst Burst Burst.wav")
)
local deduplicated = assert(ucs_classify_filename_keywords("AIR Burst.wav"))
assert(repeated.catid == deduplicated.catid)
assert(repeated.ucs_candidates == deduplicated.ucs_candidates)
assert(repeated.ucs_evidence == deduplicated.ucs_evidence)

local material = assert(
  ucs_classify_filename_keywords("METAL Impact Clang Heavy 01.wav")
)
assert(material.ucs_status == "auto" and material.catid == "METLImpt")

local generic = assert(ucs_classify_filename_keywords("Impact Hit 01.wav"))
assert(generic.ucs_status == "pending")

local existing = {
  name = "AIR Burst Pressure Release 01.wav",
  path = "C:/Library/AIR Burst Pressure Release 01.wav",
  ucs_status = "unclassified",
}
local existing_result, existing_reason = ucs_classify_existing_asset(existing)
assert(existing_result and existing_reason == "auto")
assert(existing_result.catid == "AIRBrst")
assert(ucs_classification_differs(existing, existing_result))
assert(ucs_assign_classification(existing, existing_result))
assert(not ucs_classification_differs(existing, existing_result))
assert(not ucs_assign_classification(existing, existing_result))

local manual = {
  name = "AIRBrst_Should Stay Manual.wav",
  ucs_status = "manual",
  catid = "USER",
}
local manual_result, manual_reason = ucs_classify_existing_asset(manual)
assert(manual_result == nil and manual_reason == "manual")
assert(manual.catid == "USER")

local pending_existing = {
  name = "Burst 01.wav",
  ucs_status = "unclassified",
}
local pending_result, pending_reason =
  ucs_classify_existing_asset(pending_existing)
assert(pending_result and pending_reason == "pending")
assert(pending_result.ucs_status == "pending")
assert(pending_result.ucs_candidates:find("AIRBrst", 1, true))

local generated = {
  name = "ZXQJ 0001.wav",
  ucs_status = "auto",
  ucs_source = "filename_keywords",
  catid = "AIRBrst",
  category = "AIR",
  subcategory = "BURST",
}
local generated_result, generated_reason = ucs_classify_existing_asset(generated)
assert(generated_result and generated_reason == "unclassified")
assert(generated_result.catid == "" and generated_result.category == "")

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

local keyword_started = os.clock()
for index = 1, keyword_scale do
  local result = assert(ucs_classify_filename_keywords(
    index % 2 == 0
        and "AIR Burst Pressure Release.wav"
      or "METAL Impact Clang Heavy.wav"
  ))
  assert(result.ucs_status == "auto")
end
local keyword_elapsed = os.clock() - keyword_started

print(string.format(
  "Lua UCS catalog self-test OK: records=753 categories=82 exact=%d/%.3fs keyword=%d/%.3fs",
  scale,
  elapsed,
  keyword_scale,
  keyword_elapsed
))
