-- @description Smart Bounce Settings / 智能合并渲染设置
-- @version 1.0
-- @author Psysia
-- @about Shared tail-detection settings. Maximum tail is fixed at 5 seconds.
local SECTION="PsysiaSmartBounce"
local function read(key, fallback)
  local v=reaper.GetExtState(SECTION,key)
  return v~="" and v or tostring(fallback)
end
local mode=read("tail_mode","auto")
local ok,result=reaper.GetUserInputs(
  "Smart Bounce Settings / 智能合并渲染设置",
  4,
  "Threshold dBFS (-100..-12),Silence hold sec (0.1..5),Safety pad sec (0..2),Tail (auto/fixed/none),extrawidth=175",
  table.concat({
    read("threshold_db",-60),read("silence_hold",1),
    read("safety_pad",0.2),mode
  },","))
if not ok then return end
local a,b,c,d=result:match("^([^,]*),([^,]*),([^,]*),([^,]*)$")
a,b,c=tonumber(a),tonumber(b),tonumber(c)
d=(d or ""):lower():gsub("%s+","")
if not a or a< -100 or a> -12 or
   not b or b<0.1 or b>5 or not c or c<0 or c>2 or
   (d~="auto" and d~="fixed" and d~="none") then
  reaper.MB("参数无效。\nThreshold: -100..-12 dBFS\n"
    .."Silence hold: 0.1..5 s\nSafety pad: 0..2 s\n"
    .."Tail: auto / fixed / none\n\n"
    .."尾音最大长度始终是 5 秒。","Smart Bounce Settings",0)
  return
end
for k,v in pairs({
  threshold_db=tostring(a),silence_hold=tostring(b),
  safety_pad=tostring(c),tail_mode=d
}) do reaper.SetExtState(SECTION,k,v,true) end
