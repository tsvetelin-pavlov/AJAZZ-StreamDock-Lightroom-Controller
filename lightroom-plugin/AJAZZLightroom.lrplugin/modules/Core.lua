---@diagnostic disable: undefined-global
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrApplication = import 'LrApplication'
local LrDevelopController = import 'LrDevelopController'
local LrHttp = import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local function load_module(path)
    local src = LrFileUtils.readFile(path)
    if not src then error('Failed to read '..path) end
    if string.byte(src,1) == 239 and string.byte(src,2) == 187 and string.byte(src,3) == 191 then
        src = string.sub(src, 4)
    end
    -- Prefer modern Lua 5.4 load(); fall back to loadstring() if the LR runtime provides it.
    local chunk, err
    local hasLoadString = type(rawget(_G, 'loadstring')) == 'function'
    if not hasLoadString and type(load) == 'function' then
        -- Lua 5.2+: load(string, chunkname, mode, env)
        chunk, err = load(src, '@'..path, 't', _G)
    else
        -- Lightroom's Lua 5.1: use loadstring
        ---@diagnostic disable-next-line: deprecated
        chunk, err = loadstring(src, '@'..path)
    end
    if not chunk then error('load error: '..tostring(err)) end
    local ok, mod = pcall(chunk)
    if not ok then error('exec error: '..tostring(mod)) end
    return mod
end

local paramPath = LrPathUtils.child(_PLUGIN.path, 'modules/ParamMap.lua')
local ParamMap = load_module(paramPath)

local Core = {}
Core.running = Core.running == true -- preserve if reloaded
Core.pollUrl = 'http://127.0.0.1:58762/poll'
Core.ackUrl = 'http://127.0.0.1:58762/ack'

local function ensureDevelop()
    local _ = LrApplication.activeCatalog()
    return true
end

local function applyDelta(target, delta)
    local dc = LrDevelopController
    local t = target
    local name = ParamMap[t]
    if name then
        pcall(function() dc.increment(name, delta) end)
        return
    end
    if t:match('^HSL') then
        local _, _, group, color = t:find('HSL%.(Hue|Sat|Lum)%.([A-Za-z]+)')
        if group and color then
            local map = { Hue = 'HSL Hue ', Sat = 'HSL Saturation ', Lum = 'HSL Luminance ' }
            local ctrl = map[group] .. color
            pcall(function() dc.increment(ctrl, delta) end)
            return
        end
    end
    if t == 'Exposure2012' then dc.increment("Exposure", delta)
    elseif t == 'Contrast2012' then dc.increment("Contrast", delta)
    elseif t == 'Highlights2012' then dc.increment("Highlights", delta)
    elseif t == 'Shadows2012' then dc.increment("Shadows", delta)
    elseif t == 'Whites2012' then dc.increment("Whites", delta)
    elseif t == 'Blacks2012' then dc.increment("Blacks", delta)
    elseif t == 'Clarity2012' or t == 'Clarity' then dc.increment("Clarity", delta)
    elseif t == 'Dehaze' then dc.increment("Dehaze", delta)
    elseif t == 'Vibrance' then dc.increment("Vibrance", delta)
    elseif t == 'Saturation' then dc.increment("Saturation", delta)
    elseif t == 'Texture' then dc.increment("Texture", delta)
    elseif t == 'Temperature' or t == 'Temp' then dc.increment("Temperature", delta * 100)
    elseif t == 'Tint' then dc.increment("Tint", delta * 100)
    elseif t:match('^HSL') then
        local _, _, group, color = t:find('HSL%.(Hue|Sat|Lum)%.([A-Za-z]+)')
        if group and color then
            local map = { Hue = 'HSL Hue ', Sat = 'HSL Saturation ', Lum = 'HSL Luminance ' }
            local name = map[group] .. color
            dc.increment(name, delta)
        end
    end
    -- Fallback: attempt direct name increment
    pcall(function() dc.increment(t, delta) end)
end

local function setAbsolute(target, value01)
    local dc = LrDevelopController
    local t = target
    local name = ParamMap[t]
    if name then
        pcall(function() dc.setValue(name, value01) end)
        return
    end
    if t:match('^HSL') then
        local _, _, group, color = t:find('HSL%.(Hue|Sat|Lum)%.([A-Za-z]+)')
        if group and color then
            local map = { Hue = 'HSL Hue ', Sat = 'HSL Saturation ', Lum = 'HSL Luminance ' }
            local ctrl = map[group] .. color
            pcall(function() dc.setValue(ctrl, value01) end)
            return
        end
    end
    if t == 'Exposure2012' then dc.setValue("Exposure", value01)
    elseif t == 'Contrast2012' then dc.setValue("Contrast", value01)
    elseif t == 'Highlights2012' then dc.setValue("Highlights", value01)
    elseif t == 'Shadows2012' then dc.setValue("Shadows", value01)
    elseif t == 'Whites2012' then dc.setValue("Whites", value01)
    elseif t == 'Blacks2012' then dc.setValue("Blacks", value01)
    elseif t == 'Clarity2012' or t == 'Clarity' then dc.setValue("Clarity", value01)
    elseif t == 'Dehaze' then dc.setValue("Dehaze", value01)
    elseif t == 'Vibrance' then dc.setValue("Vibrance", value01)
    elseif t == 'Saturation' then dc.setValue("Saturation", value01)
    elseif t == 'Texture' then dc.setValue("Texture", value01)
    elseif t == 'Temperature' or t == 'Temp' then dc.setValue("Temperature", value01)
    elseif t == 'Tint' then dc.setValue("Tint", value01)
    end
    -- Fallback: attempt direct set
    pcall(function() dc.setValue(t, value01) end)
end

local function invokeAction(action)
    local dc = LrDevelopController
    if action == 'ToggleBeforeAfter' then dc.performCommand('toggleBeforeAfter')
    elseif action == 'Reset' then dc.performCommand('resetSettings')
    elseif action == 'CopySettings' then dc.performCommand('copySettings')
    elseif action == 'PasteSettings' then dc.performCommand('pasteSettings')
    else
        pcall(function() dc.performCommand(action) end)
    end
end

local function handle(cmd)
    if not (cmd and cmd.type) then return end
    ensureDevelop()
    if cmd.type == 'delta' and cmd.target and cmd.value then
        applyDelta(cmd.target, cmd.value)
    elseif cmd.type == 'set' and cmd.target and cmd.value then
        setAbsolute(cmd.target, cmd.value)
    elseif cmd.type == 'invoke' and cmd.target then
        invokeAction(cmd.target)
    end
end

local function pollOnce()
    local resp, hdrs = LrHttp.get(Core.pollUrl, nil, 10)
    if not resp or #resp == 0 then return end
    -- Parse Lua table literal: prefer load() in 5.2+, fallback to loadstring in LR 5.1
    local chunk, err
    local hasLoadString = type(rawget(_G, 'loadstring')) == 'function'
    if not hasLoadString and type(load) == 'function' then
        chunk, err = load('return ' .. resp, '=(poll)', 't', _G)
    else
        ---@diagnostic disable-next-line: deprecated
        chunk, err = loadstring('return ' .. resp)
    end
    if type(chunk) ~= 'function' then return end
    local ok, cmd = pcall(chunk)
    if ok and type(cmd) == 'table' then
        handle(cmd)
        LrHttp.post(Core.ackUrl, 'ok')
    end
end

function Core.start()
    if Core.running then return end
    Core.running = true
    LrDialogs.message('AJAZZ StreamDock poller starting')
    LrTasks.startAsyncTask(function()
        while Core.running do
            pollOnce()
            LrTasks.sleep(0.02)
        end
    end)
end

function Core.stop()
    Core.running = false
end

return Core
