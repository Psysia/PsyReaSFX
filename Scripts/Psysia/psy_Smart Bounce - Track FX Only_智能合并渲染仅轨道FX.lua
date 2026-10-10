-- @description Smart Bounce - Track FX Only / 智能合并渲染 - 仅轨道FX
-- @version 1.0.2
-- @author Psysia
-- @about One merged WAV at original position; current-track FX only.
local _,script=reaper.get_action_context()
local dir=script:match("^(.*[/\\])")
if not dir then reaper.MB("无法定位脚本目录。","Smart Bounce",0); return end
local ok,module=pcall(dofile,dir.."psy_Smart Bounce Core.lua")
if not ok then reaper.MB("Smart Bounce Core 缺失或加载失败：\n"..tostring(module),"Smart Bounce",0); return end
module.run(false)
