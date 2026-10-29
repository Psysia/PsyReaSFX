local function key(path) return path:gsub("\\", "/"):gsub("/+$", ""):lower() end
function path_key(path) return key(path) end
function dirname(path) return path:gsub("\\", "/"):match("^(.*)/[^/]+$") or "" end
function basename(path) return path:gsub("\\", "/"):match("([^/]+)$") or "" end
function path_is_inside(path,root)
  local p,r=key(path),key(root) return p==r or p:sub(1,#r+1)==r.."/"
end
assert(loadfile("src/lua/46_product_navigation.lua"))()
local function asset(folder, name) return {folder=folder,path=folder.."/"..(name or "effect.wav"),name=name or "effect.wav"} end
local function expect(item,hints,target,reason)
  local actual,why=resolve_asset_product_folder(item,hints)
  assert(actual==target and why==reason, tostring(actual).." ("..tostring(why)..") expected "..target.." ("..reason..")")
end
local base="C:/Sound Effect Library Aki/2026 0630"
local ghost=base.."/Ghosthack Sounds Ultimate"
expect(asset(ghost.."/WAV/Footsteps"),{},ghost,"name")
local urban=base.."/Urban Streets"
expect(asset(urban.."/WAV/Footsteps"),{metadata_names={"Urban Streets"}},urban,"metadata")
expect(asset(urban.."/Urban Streets Interior"),{metadata_names={"Urban Streets"}},urban,"metadata")
local boom=base.."/BOOM Library Complete Collection"
local hits=boom.."/BOOM Library - Cinematic Hits"
local trailers=boom.."/BOOM Library - Cinematic Trailers"
expect(asset(hits.."/WAV/Hits"),{metadata_names={"BOOM Library", "Cinematic Hits"}},hits,"metadata")
expect(asset(trailers.."/WAV/Whooshes"),{metadata_names={"Cinematic Trailers"}},trailers,"metadata")
expect(asset(hits.."/WAV/Hits"),{cover_path=boom.."/cover.jpg"},hits,"name")
expect(asset(hits.."/WAV/Hits"),{},hits,"name")
expect(asset(hits.."/WAV/Hits"),{cover_path=boom.."/cover.jpg",
  cover_at=function(folder) return folder.."/cover.jpg" end, same_artwork=function() return true end},hits,"cover")
expect(asset(boom.."/Unknown/Footsteps"),{metadata_names={"BOOM Library"},cover_path=boom.."/cover.jpg"},
  boom.."/Unknown/Footsteps","folder")
local boom_sounds=base.."/BOOM Sound Effects Collection"
expect(asset(boom_sounds.."/Unknown/Footsteps"),{cover_path=boom_sounds.."/cover.jpg"},
  boom_sounds.."/Unknown/Footsteps","folder")
expect(asset(base.."/Random/WAV/Footsteps"),{metadata_names={"Footsteps","Aki","2026"}},base.."/Random/WAV/Footsteps","folder")
local unknown=base.."/Unnamed Product"
expect(asset(unknown.."/WAV/Footsteps"),{cover_path=unknown.."/cover.jpg"},unknown,"cover")
expect(asset(unknown.."/1. Audio/Stereo/Footsteps"),{cover_path=unknown.."/2. Artwork/images/cover.jpg"},unknown,"cover")
expect(asset(ghost.."/WAV/Footsteps"),{cover_path=ghost.."/WAV/Footsteps/cover.jpg"},ghost,"cover")
-- Identical copies across category/parent covers choose the outer matching
-- product, while a different cover above it stops expansion.
local examined={}
expect(asset(unknown.."/Footsteps"),{cover_path=unknown.."/Footsteps/cover.jpg",
  cover_at=function(folder) examined[#examined+1]=folder return folder.."/cover.jpg" end,
  same_artwork=function(_,right) return path_is_inside(right,unknown) end},unknown,"cover")
assert(#examined<=ProductNavigation.max_parents+1)
-- A manually shared umbrella cover must not merge every product under Aki.
expect(asset(base.."/Random/Footsteps"),{root=base,cover_path=base.."/cover.jpg"},base.."/Random/Footsteps","folder")
expect(asset(base.."/Random/Footsteps"),{cover_path="D:/unrelated/cover.jpg"},base.."/Random/Footsteps","folder")
expect(asset(base.."/Random/Footsteps"),{metadata_names={"BOOM Library","WAV","Audio"}},base.."/Random/Footsteps","folder")
local cn=base.."/机械音效套装"
expect(asset(cn.."/WAV/启动"),{metadata_names={"机械音效套装"}},cn,"metadata")
expect(asset("//server/share/Unknown/Footsteps"),{},"//server/share/Unknown/Footsteps","folder")
-- No unbounded walk to a distant title.
local deep=urban.."/1/2/3/4/5/6/7/8"
expect(asset(deep),{metadata_names={"Urban Streets"}},deep,"folder")
local names=product_navigation_metadata_names({["RIFF:IPRD"]="Urban Streets",["ID3:TALB"]="Another Album",
  ["iXML:USER:Library"]="Urban Streets",["iXML:USER:ProductName"]="Exact Product",
  ["RIFF:INAM"]="Single file title",["iXML:USER:LibraryDescription"]="Not a product field"})
assert(names[1]=="Exact Product" and #names==4)
for i=1,300 do product_navigation_remember_metadata({},tostring(i),{tostring(i)}) end
assert(#ProductNavigation.metadata_order==256)

-- Exercise runtime metadata lookup and cover comparison using temporary files.
local f=assert(io.open("src/lua/50_runtime_ui.lua","rb")) local runtime=f:read("*a") f:close()
local start=assert(runtime:find("function product_navigation_source_names(asset)",1,true))
local finish=assert(runtime:find("function browse_asset_library(asset)",start,true))
local destroyed,opened=0,0
state={library_by_id={a={name="Aki"}},artwork_folder_cache={}}
function metadata_map() return {["iXML:USER:Library"]="Urban Streets"} end
reaper={PCM_Source_CreateFromFile=function() opened=opened+1 return {} end,
  PCM_Source_Destroy=function() destroyed=destroyed+1 end}
assert(load(runtime:sub(start,finish-1)))()
local item=asset(urban.."/WAV") item.library="Aki" item.library_id="a"
assert(product_navigation_source_names(item)[1]=="Urban Streets" and destroyed==1)
assert(product_navigation_source_names(item)[1]=="Urban Streets" and opened==1)
local a,b=os.tmpname(),os.tmpname()
local function write(path,data) local handle=assert(io.open(path,"wb")) handle:write(data) handle:close() end
write(a,"same cover bytes") write(b,"same cover bytes")
assert(product_navigation_same_artwork(a,b))
write(b,"different cover bytes") assert(not product_navigation_same_artwork(a,b))
write(a,string.rep("x",ProductNavigation.artwork_max_bytes+1)) assert(not product_navigation_same_artwork(a,b))
os.remove(a) os.remove(b)
print("Lua product navigation self-test passed: product metadata, cover ownership/copies, parent limits, generic-folder fallback and runtime cache")
