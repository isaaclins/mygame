local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local Settings = require("functions/settings")

local SettingsState = {}

local dragging = nil
local from_pause = false

function SettingsState:init(opts)
    opts = opts or {}
    from_pause = opts.from_pause or false
    dragging = nil
end

local function drawSlider(label, x, y, w, value, key)
    local h = 8
    local knob_r = 12
    local track_y = y + 22

    love.graphics.setFont(Fonts.get(15))
    UI.setColor(UI.colors.text)
    love.graphics.print(label, x, y)

    local pct_text = tostring(math.floor(value * 100)) .. "%"
    UI.setColor(UI.colors.text_dim)
    love.graphics.printf(pct_text, x, y, w, "right")

    UI.setColor(UI.colors.panel_light)
    UI.roundRect("fill", x, track_y, w, h, 4)

    local fill_w = value * w
    UI.setColor(UI.colors.accent)
    UI.roundRect("fill", x, track_y, fill_w, h, 4)

    local knob_x = x + fill_w
    local knob_y = track_y + h / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", knob_x, knob_y, knob_r)
    UI.setColor(UI.colors.accent)
    love.graphics.circle("fill", knob_x, knob_y, knob_r - 2)

    return {
        key = key,
        x = x, y = track_y - knob_r,
        w = w, h = h + knob_r * 2,
        track_x = x, track_w = w,
    }
end

local function drawToggle(label, x, y, w, value, key)
    love.graphics.setFont(Fonts.get(15))
    UI.setColor(UI.colors.text)
    love.graphics.print(label, x, y + 2)

    local box_size = 24
    local bx = x + w - box_size
    local by = y + 2

    if value then
        UI.setColor(UI.colors.green)
    else
        UI.setColor(UI.colors.panel_light)
    end
    UI.roundRect("fill", bx, by, box_size, box_size, 4)

    if value then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(Fonts.get(16))
        love.graphics.printf("✓", bx, by + 2, box_size, "center")
    end

    return {
        key = key,
        x = bx, y = by,
        w = box_size, h = box_size,
        is_toggle = true,
    }
end

function SettingsState:draw()
    local W, H = love.graphics.getDimensions()

    if from_pause then
        love.graphics.setColor(0, 0, 0, 0.75)
        love.graphics.rectangle("fill", 0, 0, W, H)
    else
        UI.setColor(UI.colors.bg)
        love.graphics.rectangle("fill", 0, 0, W, H)
    end

    local panel_w, panel_h = 420, 460
    local px = (W - panel_w) / 2
    local py = (H - panel_h) / 2

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent, border_width = 2 })

    love.graphics.setFont(Fonts.get(30))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("SETTINGS", px, py + 16, panel_w, "center")

    local content_x = px + 30
    local content_w = panel_w - 60
    local row_y = py + 70

    self._sliders = {}
    self._toggles = {}

    local s1 = drawSlider("Master Volume", content_x, row_y, content_w, Settings.get("master_volume"), "master_volume")
    table.insert(self._sliders, s1)
    row_y = row_y + 56

    local s2 = drawSlider("Music Volume", content_x, row_y, content_w, Settings.get("music_volume"), "music_volume")
    table.insert(self._sliders, s2)
    row_y = row_y + 70

    local t1 = drawToggle("Pause on Unfocus", content_x, row_y, content_w, Settings.get("pause_on_unfocus"), "pause_on_unfocus")
    table.insert(self._toggles, t1)
    row_y = row_y + 40

    local t2 = drawToggle("Screen Shake", content_x, row_y, content_w, Settings.get("screenshake"), "screenshake")
    table.insert(self._toggles, t2)
    row_y = row_y + 40

    local t3 = drawToggle("Show FPS", content_x, row_y, content_w, Settings.get("show_fps"), "show_fps")
    table.insert(self._toggles, t3)
    row_y = row_y + 40

    local t4 = drawToggle("VSync", content_x, row_y, content_w, Settings.get("vsync"), "vsync")
    table.insert(self._toggles, t4)
    row_y = row_y + 50

    local btn_w, btn_h = 140, 44
    local btn_gap = 20

    self._back_hovered = UI.drawButton(
        "BACK", px + panel_w / 2 - btn_w - btn_gap / 2, py + panel_h - 62, btn_w, btn_h,
        { font = Fonts.get(20), color = UI.colors.blue }
    )

    self._reset_hovered = UI.drawButton(
        "RESET", px + panel_w / 2 + btn_gap / 2, py + panel_h - 62, btn_w, btn_h,
        { font = Fonts.get(20), color = UI.colors.red, hover_color = { 0.95, 0.30, 0.30, 1 } }
    )
end

function SettingsState:update(dt)
    if dragging then
        local mx = love.mouse.getX()
        local slider = dragging
        local val = (mx - slider.track_x) / slider.track_w
        val = math.max(0, math.min(1, val))
        Settings.set(slider.key, val)
    end
end

function SettingsState:mousepressed(x, y, button)
    if button ~= 1 then return nil end

    for _, slider in ipairs(self._sliders or {}) do
        if UI.pointInRect(x, y, slider.x, slider.y, slider.w, slider.h) then
            dragging = slider
            local val = (x - slider.track_x) / slider.track_w
            val = math.max(0, math.min(1, val))
            Settings.set(slider.key, val)
            return nil
        end
    end

    for _, toggle in ipairs(self._toggles or {}) do
        if UI.pointInRect(x, y, toggle.x, toggle.y, toggle.w, toggle.h) then
            Settings.set(toggle.key, not Settings.get(toggle.key))
            return nil
        end
    end

    if self._back_hovered then
        Settings.save()
        return "settings_back"
    end

    if self._reset_hovered then
        Settings.reset()
        return nil
    end

    return nil
end

function SettingsState:mousereleased(x, y, button)
    if button == 1 then
        dragging = nil
    end
end

function SettingsState:keypressed(key)
    if key == "escape" then
        Settings.save()
        return "settings_back"
    end
    return nil
end

return SettingsState
