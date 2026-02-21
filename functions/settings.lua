local Settings = {}

local SETTINGS_FILE = "settings.lua"

local defaults = {
    music_volume = 0.5,
    master_volume = 1.0,
    pause_on_unfocus = true,
    screenshake = true,
    show_fps = false,
    vsync = true,
}

local current = {}

for k, v in pairs(defaults) do
    current[k] = v
end

function Settings.get(key)
    return current[key]
end

function Settings.set(key, value)
    current[key] = value
end

function Settings.save()
    local lines = { "return {" }
    for k, v in pairs(current) do
        if type(v) == "boolean" then
            table.insert(lines, string.format("  %s = %s,", k, tostring(v)))
        elseif type(v) == "number" then
            table.insert(lines, string.format("  %s = %s,", k, tostring(v)))
        elseif type(v) == "string" then
            table.insert(lines, string.format("  %s = %q,", k, v))
        end
    end
    table.insert(lines, "}")
    love.filesystem.write(SETTINGS_FILE, table.concat(lines, "\n") .. "\n")
end

function Settings.load()
    if not love.filesystem.getInfo(SETTINGS_FILE) then return end
    local chunk, err = love.filesystem.load(SETTINGS_FILE)
    if not chunk then return end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then return end
    for k, v in pairs(data) do
        if defaults[k] ~= nil then
            current[k] = v
        end
    end
end

function Settings.reset()
    for k, v in pairs(defaults) do
        current[k] = v
    end
end

function Settings.getDefaults()
    return defaults
end

return Settings
