---@diagnostic disable: undefined-global
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrDialogs = import 'LrDialogs'

local function load_module(path)
	local src = LrFileUtils.readFile(path)
	if not src then error('Failed to read '..path) end
	if string.byte(src,1) == 239 and string.byte(src,2) == 187 and string.byte(src,3) == 191 then
		src = string.sub(src, 4)
	end
	-- Prefer modern Lua 5.4 load(); fall back to loadstring() if available in Lightroom's runtime.
	local chunk, err
	local hasLoadString = type(rawget(_G, 'loadstring')) == 'function'
	if not hasLoadString and type(load) == 'function' then
		chunk, err = load(src, '@'..path, 't', _G)
	else
		---@diagnostic disable-next-line: deprecated
		chunk, err = loadstring(src, '@'..path)
	end
	if not chunk then error('load error: '..tostring(err)) end
	local ok, mod = pcall(chunk)
	if not ok then error('exec error: '..tostring(mod)) end
	return mod
end

-- Load Core.lua from this plugin's modules folder explicitly
local corePath = LrPathUtils.child(_PLUGIN.path, 'modules/Core.lua')
local Core = _G.__AJAZZ_CORE or load_module(corePath)
_G.__AJAZZ_CORE = Core
if not (Core and Core.running) then
	LrDialogs.message('AJAZZ StreamDock server is not running')
	return true
end
Core.stop()
return true
