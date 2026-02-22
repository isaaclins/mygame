local Settings = {}

local SETTINGS_FILE = "settings.lua"

local defaults = {
    music_volume = 0.5,
    master_volume = 1.0,
    pause_on_unfocus = true,
    screenshake = true,
    show_fps = false,
    vsync = true,
    fullscreen = false,
    dice_sort_mode = "default",
    keybind_select_next = "tab",
    keybind_move_left = "left",
    keybind_move_right = "right",
    keybind_toggle_lock = "space",
    keybind_reroll = "r",
    keybind_score = "return",
    keybind_sort_cycle = "q",
    keybind_show_tooltip = "e",
}

local key_display = {
    ["return"] = "Enter",
    ["space"] = "Space",
    ["tab"] = "Tab",
    ["escape"] = "Esc",
    ["left"] = "Left",
    ["right"] = "Right",
    ["up"] = "Up",
    ["down"] = "Down",
    ["lshift"] = "LShift",
    ["rshift"] = "RShift",
    ["lctrl"] = "LCtrl",
    ["rctrl"] = "RCtrl",
    ["lalt"] = "LAlt",
    ["ralt"] = "RAlt",
    ["backspace"] = "Bksp",
    ["delete"] = "Del",
    ["capslock"] = "Caps",
    ["insert"] = "Ins",
    ["home"] = "Home",
    ["end"] = "End",
    ["pageup"] = "PgUp",
    ["pagedown"] = "PgDn",
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

function Settings.getKeyName(key)
    if not key then return "None" end
    return key_display[key] or key:upper()
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

function Settings.resetKeybinds()
    for k, v in pairs(defaults) do
        if k:sub(1, 8) == "keybind_" then
            current[k] = v
        end
    end
end

function Settings.getDefaults()
    return defaults
end

return Settings
