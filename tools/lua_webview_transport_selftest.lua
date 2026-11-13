-- Exercise the production transport with a deliberately blocked native queue.
-- No native windows, REAPER processes or user files are opened.
local function read(path)
  local file = assert(io.open(path, "rb"))
  local source = file:read("*a")
  file:close()
  return source
end
local function section(source, first, last)
  local at = assert(source:find(first, 1, true), first)
  local stop = assert(source:find(last, at + #first, true), last)
  return source:sub(at, stop - 1)
end
local source = read(arg[1] or "src/lua/48_webview.lua")
local json = read(arg[2] or "src/lua/43_neural_similarity.lua")
assert(load(section(json, "function neural_json_escape(", "function neural_windows_quote_argument(")))()
local sent, incoming, blocked, closed = {}, {}, true, false
WebUI = { protocol = 1, window = 77, next_publish = 1, outbox = {}, handlers = {} }
state = {}
reaper = {
  ReaWeb_Send = function(_, encoded)
    if blocked then return false end
    sent[#sent + 1] = neural_json_decode(encoded)
    return true
  end,
  ReaWeb_Close = function() closed = true end,
  ReaWeb_Receive = function() return table.remove(incoming, 1) or "" end,
  time_precise = function() return 0 end,
}
function ai_semantic_redact(value) return value end
function WebUI.process_arrange_drag() end
local send = assert(load(section(source, "local function send(message)", "local function waveform(")
  .. section(source, "local function rpc_params_valid(", "function WebUI.playback_timing()")
  .. "\nreturn send"))()

send({ protocol = 1, event = "state", data = { revision = 1 } })
blocked = false
send({ protocol = 1, id = "new-response", ok = true, result = true })
assert(#sent == 0 and #WebUI.outbox == 2,
  "a recovered native queue must not deliver a newer response ahead of an older snapshot")
for _, encoded in ipairs(WebUI.outbox) do assert(reaper.ReaWeb_Send(77, encoded)) end
assert(sent[1].data.revision == 1 and sent[2].id == "new-response", "backpressure must preserve FIFO order")
WebUI.outbox, sent = {}, {}

local mutations = 0
WebUI.handlers["fixture.mutate"] = function(params)
  mutations = mutations + 1
  return params.value
end
for index, params in ipairs({ true, "not an object", { 7 } }) do
  incoming = { neural_json_encode({ protocol = 1, id = "invalid-params-" .. index, method = "fixture.mutate", params = params }) }
  webview_receive()
  assert(mutations == 0, "malformed parameters must never reach a mutating handler")
  assert(sent[#sent].ok == false, "identified malformed requests must receive an explicit failure")
end
for _, params in ipairs({ "[]", "[null]", "[null,null]", "null" }) do
  incoming = { '{"protocol":1,"id":"array-params","method":"fixture.mutate","params":' .. params .. '}' }
  webview_receive()
  assert(mutations == 0 and sent[#sent].ok == false,
    "empty/null-only arrays must not be mistaken for object parameters")
end
WebUI.handlers["fixture.read"] = function(params) return next(params) == nil end
incoming = { '{"protocol":1,"id":"empty-object","method":"fixture.read","params":{}}' }
webview_receive()
assert(sent[#sent].ok and sent[#sent].result and mutations == 0, "empty object parameters must stay valid")
incoming = { '{"protocol":1,"id":"no-params","method":"fixture.read"}' }
webview_receive()
assert(sent[#sent].ok and sent[#sent].result and mutations == 0, "omitted optional parameters must stay valid")
for _, method in ipairs({ true, {}, "", string.rep("x", 129) }) do
  incoming = { neural_json_encode({ protocol = 1, id = "invalid-method", method = method }) }
  webview_receive()
  assert(mutations == 0 and sent[#sent].ok == false, "invalid methods must fail without mutation")
end
local before = #sent
incoming = { neural_json_encode({ protocol = 1, id = "", method = "fixture.mutate" }) }
webview_receive()
assert(mutations == 0 and #sent == before, "empty request IDs must not execute commands")
incoming = { neural_json_encode({ protocol = 1, id = "too-large", method = "fixture.mutate", params = { value = string.rep("x", 900000) } }) }
webview_receive()
assert(mutations == 0, "oversized requests must not execute commands")
incoming = { neural_json_encode({ protocol = 1, id = "valid", method = "fixture.mutate", params = { value = "captured" } }) }
webview_receive()
assert(mutations == 1 and sent[#sent].ok and sent[#sent].result == "captured")

blocked = true
for index = 1, 65 do send({ protocol = 1, id = tostring(index), ok = true, result = true }) end
assert(closed and #WebUI.outbox == 64, "an unconsumed queue must close at its capacity limit")
print("WebView transport passed: FIFO recovery, malformed RPC rejection and bounded backpressure")
