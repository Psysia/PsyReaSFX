-- Injectable boundary for REAPER, SWS and ReaImGui host APIs. Runtime code
-- uses the real global table; command-line tests can supply a small stub.

function new_reaper_host_adapter(api)
  assert(type(api) == "table", "host API table is required")
  local adapter = { raw = api }
  return setmetatable(adapter, {
    __index = function(target, name)
      local value = api[name]
      if type(value) ~= "function" then
        return value
      end
      local wrapper = function(...)
        return value(...)
      end
      rawset(target, name, wrapper)
      return wrapper
    end,
  })
end

function host_api_available(api, name)
  local target = api or Host
  return type(target) == "table"
    and type(target[name]) == "function"
end

Host = new_reaper_host_adapter(reaper)
