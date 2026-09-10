-- Official UCS catalog loading and deterministic classification primitives.

UCS_CATALOG_SCHEMA = "ucs_catalog_v1"
UCS_CATALOG_VERSION = "8.2.1"
UCS_CLASSIFIER_VERSION = "exact-v1"

UcsCatalog = {
  attempted = false,
  loaded = false,
  error = "",
  entries = {},
  by_catid = {},
  by_pair = {},
  categories = {},
}

function ucs_reset_catalog()
  UcsCatalog.attempted = false
  UcsCatalog.loaded = false
  UcsCatalog.error = ""
  UcsCatalog.entries = {}
  UcsCatalog.by_catid = {}
  UcsCatalog.by_pair = {}
  UcsCatalog.categories = {}
end

function ucs_pair_key(category, subcategory)
  return string.upper(trim(category or ""))
    .. "\0"
    .. string.upper(trim(subcategory or ""))
end

function ucs_header_map(fields)
  local map = {}
  for index, field in ipairs(fields or {}) do
    map[field] = index
  end
  return map
end

function ucs_field(fields, headers, name)
  local index = headers[name]
  return index and trim(fields[index] or "") or ""
end

function load_ucs_catalog(path)
  ucs_reset_catalog()
  UcsCatalog.attempted = true

  local file = io.open(path or UCS_CATALOG_PATH, "rb")
  if not file then
    UcsCatalog.error = "missing_catalog"
    return false, UcsCatalog.error
  end

  local schema = ""
  local version = ""
  local headers = nil
  local line_number = 0
  for line in file:lines() do
    line_number = line_number + 1
    line = line:gsub("[\r\n]+$", "")
    local fields = split_tsv(line)
    if fields[1] == "#schema" then
      schema = fields[2] or ""
    elseif fields[1] == "#ucs_version" then
      version = fields[2] or ""
    elseif fields[1] == "category" then
      headers = ucs_header_map(fields)
    elseif headers and fields[1] and trim(fields[1]) ~= "" then
      local entry = {
        category = ucs_field(fields, headers, "category"),
        subcategory = ucs_field(fields, headers, "subcategory"),
        catid = ucs_field(fields, headers, "catid"),
        catshort = ucs_field(fields, headers, "catshort"),
        explanation = ucs_field(fields, headers, "explanation"),
        synonyms_en = ucs_field(fields, headers, "synonyms_en"),
        category_zh = ucs_field(fields, headers, "category_zh"),
        subcategory_zh = ucs_field(fields, headers, "subcategory_zh"),
        synonyms_zh = ucs_field(fields, headers, "synonyms_zh"),
      }

      if entry.catid == ""
        or entry.category == ""
        or entry.subcategory == ""
        or UcsCatalog.by_catid[entry.catid] then
        file:close()
        ucs_reset_catalog()
        UcsCatalog.attempted = true
        UcsCatalog.error = "invalid_catalog_row:"
          .. tostring(line_number)
          .. ":"
          .. tostring(entry.catid)
        return false, UcsCatalog.error
      end

      UcsCatalog.entries[#UcsCatalog.entries + 1] = entry
      UcsCatalog.by_catid[entry.catid] = entry
      UcsCatalog.by_pair[
        ucs_pair_key(entry.category, entry.subcategory)
      ] = entry

      local category = UcsCatalog.categories[entry.category]
      if not category then
        category = {
          name = entry.category,
          name_zh = entry.category_zh,
          entries = {},
        }
        UcsCatalog.categories[entry.category] = category
      end
      category.entries[#category.entries + 1] = entry
    end
  end
  file:close()

  if schema ~= UCS_CATALOG_SCHEMA
    or version ~= UCS_CATALOG_VERSION
    or #UcsCatalog.entries ~= 753 then
    ucs_reset_catalog()
    UcsCatalog.attempted = true
    UcsCatalog.error = "unsupported_catalog"
    return false, UcsCatalog.error
  end

  UcsCatalog.loaded = true
  return true, #UcsCatalog.entries
end

function ensure_ucs_catalog()
  if UcsCatalog.loaded then return true end
  if UcsCatalog.attempted then return false end
  return load_ucs_catalog(UCS_CATALOG_PATH)
end

function ucs_classification_result(entry, status, source)
  if not entry then return nil end
  return {
    catid = entry.catid,
    category = entry.category,
    subcategory = entry.subcategory,
    ucs_status = status or "exact",
    ucs_source = source or "filename",
    ucs_version = UCS_CATALOG_VERSION,
    ucs_classifier_version = UCS_CLASSIFIER_VERSION,
    ucs_confidence = 1,
  }
end

function ucs_classify_filename_exact(filename)
  if not ensure_ucs_catalog() then return nil end
  local stem = strip_extension(basename(filename or ""))
  local token = stem:match("^([A-Za-z0-9]+)[_%-%s]")
    or stem:match("^([A-Za-z0-9]+)$")
  if not token then return nil end
  return ucs_classification_result(
    UcsCatalog.by_catid[token],
    "exact",
    "filename"
  )
end

function ucs_classify_metadata(catid, category, subcategory)
  if not ensure_ucs_catalog() then return nil end
  local entry = UcsCatalog.by_catid[trim(catid or "")]
  if not entry and trim(category or "") ~= ""
    and trim(subcategory or "") ~= "" then
    entry = UcsCatalog.by_pair[
      ucs_pair_key(category, subcategory)
    ]
  end
  return ucs_classification_result(entry, "exact", "metadata")
end

function ucs_metadata_identifier_key(identifier)
  local text = string.upper(trim(identifier or ""))
  local leaf = text:match("([^:/\\%.]+)$") or text
  return leaf:gsub("[^A-Z0-9]", "")
end

function ucs_metadata_pick(map, names)
  local ordered_keys = {}
  for key in pairs(map or {}) do
    ordered_keys[#ordered_keys + 1] = key
  end
  table.sort(ordered_keys)

  for _, name in ipairs(names or {}) do
    local wanted = ucs_metadata_identifier_key(name)
    for _, key in ipairs(ordered_keys) do
      if ucs_metadata_identifier_key(key) == wanted then
        return tostring(map[key] or "")
      end
    end
  end
  return ""
end
