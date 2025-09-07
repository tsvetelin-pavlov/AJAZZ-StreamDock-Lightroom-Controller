---@diagnostic disable: undefined-global
local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrApplication = import 'LrApplication'
local LrDevelopController = import 'LrDevelopController'
local LrHttp = import 'LrHttp'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local Core = {}
Core.running = Core.running == true -- preserve if reloaded
Core.pollUrl = 'http://127.0.0.1:58762/poll'
Core.ackUrl = 'http://127.0.0.1:58762/ack'

-- Helper: get current value, add delta, set new value
local function setValueWithDelta(param, delta)
    local ok, current = pcall(function() return LrDevelopController.getValue(param) end)
    if not ok or type(current) ~= 'number' then
        LrDialogs.message('AJAZZ StreamDock: Could not get current value for '..tostring(param))
        return
    end
    local newValue = current + delta
    pcall(function() LrDevelopController.setValue(param, newValue) end)
end


local function load_module(path)
    local src = LrFileUtils.readFile(path)
    if not src then error('Failed to read ' .. path) end
    if string.byte(src, 1) == 239 and string.byte(src, 2) == 187 and string.byte(src, 3) == 191 then
        src = string.sub(src, 4)
    end
    -- Prefer modern Lua 5.4 load(); fall back to loadstring() if the LR runtime provides it.
    local chunk, err
    local hasLoadString = type(rawget(_G, 'loadstring')) == 'function'
    if not hasLoadString and type(load) == 'function' then
        -- Lua 5.2+: load(string, chunkname, mode, env)
        chunk, err = load(src, '@' .. path, 't', _G)
    else
        -- Lightroom's Lua 5.1: use loadstring
        ---@diagnostic disable-next-line: deprecated
        chunk, err = loadstring(src, '@' .. path)
    end
    if not chunk then error('load error: ' .. tostring(err)) end
    local ok, mod = pcall(chunk)
    if not ok then error('exec error: ' .. tostring(mod)) end
    return mod
end

local paramPath = LrPathUtils.child(_PLUGIN.path, 'modules/ParamMap.lua')
local ParamMap = load_module(paramPath)

local function ensureDevelop()
    local _ = LrApplication.activeCatalog()
    return true
end

local function applyDelta(target, delta)
    local dc = LrDevelopController
    local t = target
    local name = ParamMap[t]

    -- Always use the sign of delta as received
    if name then
        setValueWithDelta(name, delta)
        return
    end
    if t:match('^HSL') then
        local _, _, group, color = t:find('HSL%.(Hue|Sat|Lum)%.([A-Za-z]+)')
        if group and color then
            local map = { Hue = 'HSL Hue ', Sat = 'HSL Saturation ', Lum = 'HSL Luminance ' }
            local ctrl = map[group] .. color
            setValueWithDelta(ctrl, delta)
            return
        end
    end
    -- All direct mappings use delta as-is
    local directMap = {
        Exposure2012 = "Exposure",
        Contrast2012 = "Contrast",
        Highlights2012 = "Highlights",
        Shadows2012 = "Shadows",
        Whites2012 = "Whites",
        Blacks2012 = "Blacks",
        Clarity2012 = "Clarity",
        Clarity = "Clarity",
        Dehaze = "Dehaze",
        Vibrance = "Vibrance",
        Saturation = "Saturation",
        Texture = "Texture",
    }
    if directMap[t] then
        setValueWithDelta(directMap[t], delta)
        return
    end
    if t == 'Temperature' or t == 'Temp' then
        setValueWithDelta("Temperature", delta * 100)
        return
    end
    if t == 'Tint' then
        setValueWithDelta("Tint", delta * 100)
        return
    end
    -- Fallback: attempt direct name increment
    setValueWithDelta(t, delta)
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
        local directMap = {
            Exposure2012 = "Exposure",
            Contrast2012 = "Contrast",
            Highlights2012 = "Highlights",
            Shadows2012 = "Shadows",
            Whites2012 = "Whites",
            Blacks2012 = "Blacks",
            Clarity2012 = "Clarity",
            Clarity = "Clarity",
            Dehaze = "Dehaze",
            Vibrance = "Vibrance",
            Saturation = "Saturation",
            Texture = "Texture",
        }
        if directMap[t] then
            dc.setValue(directMap[t], value01)
            return
        end
        if t == 'Temperature' or t == 'Temp' then
            dc.setValue("Temperature", value01)
            return
        end
        if t == 'Tint' then
            dc.setValue("Tint", value01)
            return
        end
    -- Fallback: attempt direct set
    pcall(function() dc.setValue(t, value01) end)
end

local function invokeAction(action)
    local dc = LrDevelopController
    local ok, err
    if action == 'ToggleBeforeAfter' then
        -- performCommand is not available in all SDK versions
        if type(dc.performCommand) == 'function' then
            ok, err = pcall(function() dc.performCommand('toggleBeforeAfter') end)
        else
            LrDialogs.message('AJAZZ StreamDock: Before/After toggle is not supported in this Lightroom version.')
            return
        end
    elseif action == 'Reset' then
        if type(dc.performCommand) == 'function' then
            ok, err = pcall(function() dc.performCommand('resetSettings') end)
        else
            LrDialogs.message('AJAZZ StreamDock: Reset is not supported in this Lightroom version.')
            return
        end
    elseif action == 'CopySettings' then
        if type(dc.performCommand) == 'function' then
            ok, err = pcall(function() dc.performCommand('copySettings') end)
        else
            LrDialogs.message('AJAZZ StreamDock: Copy Settings is not supported in this Lightroom version.')
            return
        end
    elseif action == 'PasteSettings' then
        if type(dc.performCommand) == 'function' then
            ok, err = pcall(function() dc.performCommand('pasteSettings') end)
        else
            LrDialogs.message('AJAZZ StreamDock: Paste Settings is not supported in this Lightroom version.')
            return
        end
    else
        if type(dc.performCommand) == 'function' then
            ok, err = pcall(function() dc.performCommand(action) end)
        else
            LrDialogs.message('AJAZZ StreamDock: Action '..tostring(action)..' is not supported in this Lightroom version.')
            return
        end
    end
    if not ok then
        LrDialogs.message('AJAZZ StreamDock: Error invoking action: '..tostring(action)..'\n'..tostring(err))
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
