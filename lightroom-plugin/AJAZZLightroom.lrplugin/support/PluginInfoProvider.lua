---@diagnostic disable: undefined-global
local LrView = import 'LrView'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrTasks = import 'LrTasks'
local LrBinding = import 'LrBinding'

local function load_module(path)
    local src = LrFileUtils.readFile(path)
    if not src then return nil end
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
    if not chunk then return nil end
    local ok, mod = pcall(chunk)
    if not ok then return nil end
    return mod
end

local function sectionsForTopOfDialog(f, props)
    -- Lightroom normally provides a property table with lifecycle helpers.
    -- If it's nil, create one to ensure methods like addCleanupHandler exist.
    if props == nil then
        props = LrBinding.makePropertyTable(_PLUGIN)
    end
    local corePath = LrPathUtils.child(_PLUGIN.path, 'modules/Core.lua')
    local Core = _G.__AJAZZ_CORE or load_module(corePath) or {}
    _G.__AJAZZ_CORE = Core
    if props.isRunning == nil then props.isRunning = Core.running == true end

    -- Add connection status property
    if props.connectionStatus == nil then props.connectionStatus = 'Unknown' end

    -- Health check for HTTP bridge
    LrTasks.startAsyncTask(function()
        local http = import 'LrHttp'
        local ok, resp = pcall(function()
            return http.get('http://127.0.0.1:58762/health')
        end)
        if ok and resp and resp:find('OK') then
            props.connectionStatus = 'Connected'
        else
            props.connectionStatus = 'Disconnected'
        end
    end)

    return {
        {
            title = 'AJAZZ StreamDock',
            synopsis = 'Lightroom Classic Develop controller',
            view = f:column {
                spacing = f:control_spacing(),
                f:static_text { title = 'Controls Lightroom Classic Develop module via local HTTP poller.' },
                f:row {
                    spacing = f:control_spacing(),
                    f:push_button {
                        title = 'Start Server',
                        enabled = LrView.bind {
                            key = 'isRunning',
                            bind_to_object = props,
                            transform = function(v) return not v end
                        },
                        action = function()
                            LrTasks.startAsyncTask(function()
                                local C = _G.__AJAZZ_CORE or load_module(corePath) or {}
                                if C and C.start then C.start() end
                                props.isRunning = true
                            end)
                        end,
                    },
                    f:push_button {
                        title = 'Stop Server',
                        enabled = LrView.bind {
                            key = 'isRunning',
                            bind_to_object = props,
                            transform = function(v) return v == true end
                        },
                        action = function()
                            LrTasks.startAsyncTask(function()
                                local C = _G.__AJAZZ_CORE or load_module(corePath) or {}
                                if C and C.stop then C.stop() end
                                props.isRunning = false
                            end)
                        end,
                    },
                    f:static_text {
                        title = LrView.bind {
                            key = 'isRunning', bind_to_object = props,
                            transform = function(v) return v and 'Status: Running' or 'Status: Stopped' end
                        }
                    },
                    f:static_text {
                        title = LrView.bind {
                            key = 'connectionStatus', bind_to_object = props,
                            transform = function(v) return 'Bridge: ' .. v end
                        }
                    }
                },
            },
        },
    }
end

return {
    sectionsForTopOfDialog = sectionsForTopOfDialog,
}
