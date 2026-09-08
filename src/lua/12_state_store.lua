-- Controlled mutation boundary for new modules. Legacy UI code still reads
-- the shared table directly, but new services can update it through this API
-- and tests can inject an isolated table without booting ReaImGui.

function new_state_store(initial_state)
  assert(type(initial_state) == "table", "state table is required")
  local store = { raw = initial_state }

  function store.get(name)
    return initial_state[name]
  end

  function store.set(name, value)
    assert(type(name) == "string" and name ~= "", "state key is required")
    initial_state[name] = value
    return value
  end

  function store.update(name, updater)
    assert(type(updater) == "function", "state updater is required")
    return store.set(name, updater(initial_state[name]))
  end

  function store.mark_dirty(name)
    return store.set(name, true)
  end

  function store.apply(values)
    assert(type(values) == "table", "state values are required")
    for name, value in pairs(values) do
      store.set(name, value)
    end
  end

  return store
end

AppState = new_state_store(state)
