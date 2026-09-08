local module_path = assert(arg[1], "state store module is required")
state = { count = 1, dirty = false }
assert(loadfile(module_path))()

assert(AppState.get("count") == 1)
assert(AppState.set("count", 2) == 2)
assert(state.count == 2)
assert(AppState.update("count", function(value) return value + 3 end) == 5)
assert(state.count == 5)
AppState.mark_dirty("dirty")
assert(state.dirty == true)
AppState.apply({ count = 8, name = "fixture" })
assert(state.count == 8 and state.name == "fixture")

local isolated = new_state_store({ value = 10 })
isolated.update("value", function(value) return value * 2 end)
assert(isolated.get("value") == 20)

print("Lua state store self-test OK")
