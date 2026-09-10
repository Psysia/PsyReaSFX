-- Official UCS catalog loading and deterministic classification primitives.

UCS_CATALOG_SCHEMA = "ucs_catalog_v1"
UCS_CATALOG_VERSION = "8.2.1"
UCS_CLASSIFIER_VERSION = "filename-keywords-v1"
UCS_RECLASSIFY_ITEMS_PER_FRAME = 256
UCS_RECLASSIFY_FRAME_BUDGET = 0.004
UCS_CLASSIFICATION_FIELDS = {
  "catid",
  "category",
  "subcategory",
  "ucs_status",
  "ucs_source",
  "ucs_version",
  "ucs_classifier_version",
  "ucs_confidence",
  "ucs_candidates",
  "ucs_evidence",
}

UcsCatalog = {
  attempted = false,
  loaded = false,
  error = "",
  entries = {},
  by_catid = {},
  by_pair = {},
  categories = {},
  term_index = {},
  max_term_words = 1,
}

function ucs_reset_catalog()
  UcsCatalog.attempted = false
  UcsCatalog.loaded = false
  UcsCatalog.error = ""
  UcsCatalog.entries = {}
  UcsCatalog.by_catid = {}
  UcsCatalog.by_pair = {}
  UcsCatalog.categories = {}
  UcsCatalog.term_index = {}
  UcsCatalog.max_term_words = 1
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

  ucs_build_term_index()
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
    ucs_candidates = "",
    ucs_evidence = "",
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

function ucs_normalize_keyword_text(value)
  local text = string.upper(tostring(value or ""))
  text = text:gsub("[_%-]+", " ")
  text = text:gsub("[%c%p]", " ")
  text = text:gsub("%s+", " ")
  return trim(text)
end

function ucs_keyword_word_count(value)
  local count = 0
  for _ in tostring(value or ""):gmatch("%S+") do
    count = count + 1
  end
  return count
end

function ucs_keyword_terms(value)
  local normalized = tostring(value or "")
    :gsub("，", ",")
    :gsub("；", ",")
    :gsub("、", ",")
  local terms = {}
  for term in (normalized .. ","):gmatch("(.-),") do
    term = ucs_normalize_keyword_text(term)
    if term ~= "" then terms[#terms + 1] = term end
  end
  return terms
end

function ucs_register_entry_term(entry_terms, value, kind, weight)
  local term = ucs_normalize_keyword_text(value)
  local word_count = ucs_keyword_word_count(term)
  if term == "" or word_count == 0 or word_count > 4 then return end
  if word_count == 1 and #term < 3 then return end

  local existing = entry_terms[term]
  if not existing or weight > existing.weight then
    entry_terms[term] = {
      kind = kind,
      weight = weight,
      word_count = word_count,
    }
  end
end

function ucs_build_term_index()
  UcsCatalog.term_index = {}
  UcsCatalog.max_term_words = 1

  for _, entry in ipairs(UcsCatalog.entries) do
    local entry_terms = {}
    ucs_register_entry_term(
      entry_terms,
      entry.category .. " " .. entry.subcategory,
      "pair",
      14
    )
    ucs_register_entry_term(
      entry_terms,
      entry.category_zh .. " " .. entry.subcategory_zh,
      "pair",
      14
    )
    ucs_register_entry_term(entry_terms, entry.subcategory, "subcategory", 8)
    ucs_register_entry_term(entry_terms, entry.subcategory_zh, "subcategory", 8)
    ucs_register_entry_term(entry_terms, entry.category, "category", 2)
    ucs_register_entry_term(entry_terms, entry.category_zh, "category", 2)

    for _, synonym in ipairs(ucs_keyword_terms(entry.synonyms_en)) do
      ucs_register_entry_term(entry_terms, synonym, "synonym", 4)
    end
    for _, synonym in ipairs(ucs_keyword_terms(entry.synonyms_zh)) do
      ucs_register_entry_term(entry_terms, synonym, "synonym", 4)
    end

    for term, info in pairs(entry_terms) do
      local postings = UcsCatalog.term_index[term]
      if not postings then
        postings = {}
        UcsCatalog.term_index[term] = postings
      end
      postings[#postings + 1] = {
        entry = entry,
        kind = info.kind,
        weight = info.weight,
      }
      UcsCatalog.max_term_words = math.max(
        UcsCatalog.max_term_words,
        info.word_count
      )
    end
  end
end

function ucs_term_inside(shorter, longer)
  return (" " .. longer .. " "):find(
    " " .. shorter .. " ",
    1,
    true
  ) ~= nil
end

function ucs_filename_query_terms(filename)
  local normalized = ucs_normalize_keyword_text(
    strip_extension(basename(filename or ""))
  )
  local words = {}
  for word in normalized:gmatch("%S+") do
    words[#words + 1] = word
  end

  local found = {}
  local max_words = math.min(UcsCatalog.max_term_words or 1, 4)
  for first = 1, #words do
    local phrase = ""
    for count = 1, math.min(max_words, #words - first + 1) do
      phrase = count == 1
          and words[first]
        or (phrase .. " " .. words[first + count - 1])
      if UcsCatalog.term_index[phrase] then found[phrase] = true end
    end
  end

  local ordered = {}
  for term in pairs(found) do ordered[#ordered + 1] = term end
  table.sort(ordered, function(a, b)
    local a_words = ucs_keyword_word_count(a)
    local b_words = ucs_keyword_word_count(b)
    if a_words ~= b_words then return a_words > b_words end
    if #a ~= #b then return #a > #b end
    return a < b
  end)

  local selected = {}
  for _, term in ipairs(ordered) do
    local nested = false
    for _, longer in ipairs(selected) do
      if ucs_term_inside(term, longer) then
        nested = true
        break
      end
    end
    if not nested then selected[#selected + 1] = term end
  end
  return selected
end

function ucs_format_candidates(candidates, limit)
  local values = {}
  for index = 1, math.min(limit or 3, #candidates) do
    local candidate = candidates[index]
    values[#values + 1] = candidate.entry.catid
      .. "="
      .. string.format("%.3f", candidate.score)
  end
  return table.concat(values, ";")
end

function ucs_classify_filename_keywords(filename, max_candidates)
  if not ensure_ucs_catalog() then return nil end
  local query_terms = ucs_filename_query_terms(filename)
  if #query_terms == 0 then return nil end

  local scores = {}
  for _, term in ipairs(query_terms) do
    local postings = UcsCatalog.term_index[term] or {}
    if #postings <= 64 then
      local divisor = 1 + math.log(math.max(1, #postings), 2)
      for _, posting in ipairs(postings) do
        local catid = posting.entry.catid
        local score = scores[catid]
        if not score then
          score = {
            entry = posting.entry,
            score = 0,
            evidence = {},
            evidence_seen = {},
            noncategory_count = 0,
            pair_match = false,
            subcategory_match = false,
            subcategory_postings = math.huge,
            category_match = false,
          }
          scores[catid] = score
        end

        score.score = score.score + posting.weight / divisor
        if not score.evidence_seen[term] then
          score.evidence_seen[term] = true
          score.evidence[#score.evidence + 1] = term
          if posting.kind ~= "category" then
            score.noncategory_count = score.noncategory_count + 1
          end
        end
        if posting.kind == "pair" then score.pair_match = true end
        if posting.kind == "category" then score.category_match = true end
        if posting.kind == "subcategory" then
          score.subcategory_match = true
          score.subcategory_postings = math.min(
            score.subcategory_postings,
            #postings
          )
        end
      end
    end
  end

  local candidates = {}
  for _, score in pairs(scores) do
    table.sort(score.evidence)
    candidates[#candidates + 1] = score
  end
  table.sort(candidates, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.entry.catid < b.entry.catid
  end)
  if #candidates == 0 then return nil end

  local top = candidates[1]
  local second_score = candidates[2] and candidates[2].score or 0
  local margin = top.score - second_score
  local qualifies = top.pair_match
    or (top.subcategory_match and top.subcategory_postings <= 2)
    or (top.category_match and top.noncategory_count >= 2)
    or top.noncategory_count >= 3
  local automatic = qualifies and top.score >= 6 and margin >= 2
  local confidence = automatic
      and math.min(0.96, 0.75 + math.min(0.15, top.score / 60)
        + math.min(0.06, margin / 30))
    or math.min(0.79, 0.45 + math.min(0.2, top.score / 50)
      + math.min(0.1, math.max(0, margin) / 30))

  local result = automatic
      and ucs_classification_result(
        top.entry,
        "auto",
        "filename_keywords"
      )
    or {
      catid = "",
      category = "",
      subcategory = "",
      ucs_status = "pending",
      ucs_source = "filename_keywords",
      ucs_version = UCS_CATALOG_VERSION,
      ucs_classifier_version = UCS_CLASSIFIER_VERSION,
    }
  result.ucs_confidence = confidence
  result.ucs_candidates = ucs_format_candidates(
    candidates,
    max_candidates or 3
  )
  result.ucs_evidence = table.concat(top.evidence, ",")
  return result
end

function ucs_unclassified_result(asset, source)
  local preserve_metadata = source == "metadata"
  return {
    catid = preserve_metadata and tostring(asset.catid or "") or "",
    category = preserve_metadata and tostring(asset.category or "") or "",
    subcategory = preserve_metadata
        and tostring(asset.subcategory or "")
      or "",
    ucs_status = preserve_metadata and "pending" or "unclassified",
    ucs_source = preserve_metadata and "metadata" or "",
    ucs_version = UCS_CATALOG_VERSION,
    ucs_classifier_version = UCS_CLASSIFIER_VERSION,
    ucs_confidence = 0,
    ucs_candidates = "",
    ucs_evidence = "",
  }
end

function ucs_classify_existing_asset(asset)
  if not asset then return nil, "missing" end
  if asset.ucs_status == "manual" then return nil, "manual" end

  local exact = ucs_classify_filename_exact(asset.name or asset.path or "")
  if exact then return exact, "exact" end

  local previous_source = tostring(asset.ucs_source or "")
  local generated_metadata = previous_source == "filename"
    or previous_source == "filename_keywords"
  if not generated_metadata then
    local metadata = ucs_classify_metadata(
      asset.catid,
      asset.category,
      asset.subcategory
    )
    if metadata then return metadata, "metadata" end
  end

  local keywords = ucs_classify_filename_keywords(
    asset.name or asset.path or ""
  )
  if keywords then
    if keywords.ucs_status == "pending" and not generated_metadata then
      keywords.catid = tostring(asset.catid or "")
      keywords.category = tostring(asset.category or "")
      keywords.subcategory = tostring(asset.subcategory or "")
    end
    return keywords, keywords.ucs_status
  end

  local has_metadata = not generated_metadata
    and (trim(asset.catid or "") ~= ""
      or trim(asset.category or "") ~= ""
      or trim(asset.subcategory or "") ~= "")
  return ucs_unclassified_result(
    asset,
    has_metadata and "metadata" or ""
  ), has_metadata and "pending" or "unclassified"
end

function ucs_classification_differs(asset, result)
  if not asset or not result then return false end
  for _, field in ipairs(UCS_CLASSIFICATION_FIELDS) do
    local current = asset[field]
    local proposed = result[field]
    if field == "ucs_confidence" then
      if math.abs((tonumber(current) or 0) - (tonumber(proposed) or 0))
        > 0.000001 then
        return true
      end
    elseif tostring(current or "") ~= tostring(proposed or "") then
      return true
    end
  end
  return false
end

function ucs_assign_classification(asset, result)
  if not asset or not result then return false end
  local changed = ucs_classification_differs(asset, result)
  if not changed then return false end
  for _, field in ipairs(UCS_CLASSIFICATION_FIELDS) do
    asset[field] = result[field]
  end
  return true
end
