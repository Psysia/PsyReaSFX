-- @description Smart Bounce - Include Parent Folder FX / 智能合并渲染 - 包含父文件夹FX
-- @version 1.0.1
-- @author Psysia
-- @about One merged WAV at original position, including the Folder FX chain.
local _,script=reaper.get_action_context()
local dir=script:match("^(.*[/\\])")
if not dir then reaper.MB("无法定位脚本目录。","Smart Bounce",0); return end
local ok,module=pcall(dofile,dir.."psy_Smart Bounce Core.lua")
if not ok then reaper.MB("Smart Bounce Core 缺失或加载失败：\n"..tostring(module),"Smart Bounce",0); return end
module.run(true)
