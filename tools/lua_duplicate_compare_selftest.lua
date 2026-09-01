local root = assert(arg[1], "temporary test directory is required")
local module_path = assert(arg[2], "duplicate comparison module is required")
local sep = package.config:sub(1, 1)

local function path(name) return root .. sep .. name end
local function write(path_value, value)
  local file = assert(io.open(path_value, "wb"))
  assert(file:write(value))
  assert(file:close())
end
local function finish(comparison)
  local result = "pending"
  local steps = 0
  while result == "pending" do
    result = step_duplicate_comparison(comparison, 4096)
    steps = steps + 1
    assert(steps < 100, "comparison did not converge")
  end
  return result, steps
end

assert(loadfile(module_path))()

local prefix = string.rep("A", 9000)
local left = path("left.bin")
local equal = path("equal.bin")
local different = path("different.bin")
local shorter = path("shorter.bin")
write(left, prefix .. "tail")
write(equal, prefix .. "tail")
write(different, string.rep("A", 5000) .. "B" .. string.rep("A", 3999) .. "tail")
write(shorter, prefix)

local equal_comparison = assert(begin_duplicate_comparison(left, equal))
local equal_result, equal_steps = finish(equal_comparison)
assert(equal_result == "equal" and equal_steps > 1)
assert(equal_comparison.bytes_compared == #prefix + 4)

assert(finish(assert(begin_duplicate_comparison(left, different))) == "different")
assert(finish(assert(begin_duplicate_comparison(left, shorter))) == "different")
local missing, missing_error = begin_duplicate_comparison(left, path("missing.bin"))
assert(not missing and missing_error == "right_open")

print("Lua duplicate comparison self-test OK")
