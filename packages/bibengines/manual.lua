return function(options)
  local src = SU.required(options, "src", "manual")

  local numeric = options.numeric
  if numeric == nil then
    numeric = true
  end

  local entries = {}
  local lineNo = 1
  for line in io.lines(src) do
    -- Skip empty lines or lines starting with # (comments)
    if not string.match(line, "^%s*(#.*)?$") then
      -- Parsing format:
      -- <key> : [cite] = <reference>
      local key, cite, reference = string.match(line, "([^%s]+)[%s]+:[%s]*([^%s=]-)[%s]*=[%s]*(.+)")

      if key == nil or reference == nil then
        SU.warn(src..":"..lineNo.." Line does not match syntax '<key> : [cite] = <reference>' (spaces are significant)")
      else
        if not numeric and (cite == nil or cite == "") then
          SU.warn(src..":"..lineNo.." No cite specified, will use key as fallback")
          cite = key
        end

        if entries[key] ~= nil then
          SU.warn(src..":"..lineNo.." Duplicate key, ignoring")
        else
          entries[key] = { cite=cite, reference=reference }
        end
      end
    end
    lineNo = lineNo + 1
  end

  local engine = {}

  function engine.citation(key, options)
    local entry = entries[key]
    if not entry then
      return
    end

    if numeric then
      entry.usedOrder = options.usedOrder
      return "["..options.usedOrder.."]"
    else
      return entry.cite
    end
  end

  function engine.bibliography(key, options)
    local entry = entries[key]
    if not entry then
      return
    end

    if numeric then
      return entry.usedOrder..". "..entry.reference
    else
      return entry.reference
    end
  end

  return engine
end