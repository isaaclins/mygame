local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local Settings = require("functions/settings")

local SettingsState = {}

local dragging = nil
local from_pause = false
local sub_view = "main"
local listening_action = nil

local keybind_actions = {
    { setting = "keybind_select_next",  label = "Select Next Die" },
    { setting = "keybind_move_left",    label = "Move Left" },
    { setting = "keybind_move_right",   label = "Move Right" },
    { setting = "keybind_toggle_lock",  label = "Toggle Lock" },
    { setting = "keybind_reroll",       label = "Reroll" },
    { setting = "keybind_score",        label = "Score / Confirm" },
    { setting = "keybind_sort_cycle",   label = "Cycle Sort Mode" },
    { setting = "keybind_show_tooltip", label = "Toggle Die Info" },
}

function SettingsState:init(opts)
    opts = opts or {}
    from_pause = opts.from_pause or false
    dragging = nil
    sub_view = "main"
    listening_action = nil
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
        love.graphics.printf("x", bx, by + 3, box_size, "center")
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

    if sub_view == "keybinds" then
        self:drawKeybindsView(W, H)
    else
        self:drawMainView(W, H)
    end
end

function SettingsState:drawMainView(W, H)
    local panel_w, panel_h = 420, 500
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
    row_y = row_y + 36

    local t2 = drawToggle("Screen Shake", content_x, row_y, content_w, Settings.get("screenshake"), "screenshake")
    table.insert(self._toggles, t2)
    row_y = row_y + 36

    local t3 = drawToggle("Show FPS", content_x, row_y, content_w, Settings.get("show_fps"), "show_fps")
    table.insert(self._toggles, t3)
    row_y = row_y + 36

    local t4 = drawToggle("VSync", content_x, row_y, content_w, Settings.get("vsync"), "vsync")
    table.insert(self._toggles, t4)
    row_y = row_y + 36

    local t5 = drawToggle("Fullscreen", content_x, row_y, content_w, Settings.get("fullscreen"), "fullscreen")
    table.insert(self._toggles, t5)

    local btn_w, btn_h = 100, 44
    local btn_gap = 12
    local btn_row_y = py + panel_h - 62
    local total_btn_w = btn_w * 3 + btn_gap * 2
    local btn_start_x = px + (panel_w - total_btn_w) / 2

    self._back_hovered = UI.drawButton(
        "BACK", btn_start_x, btn_row_y, btn_w, btn_h,
        { font = Fonts.get(18), color = UI.colors.blue }
    )

    self._keybinds_hovered = UI.drawButton(
        "KEYS", btn_start_x + btn_w + btn_gap, btn_row_y, btn_w, btn_h,
        { font = Fonts.get(18), color = UI.colors.purple }
    )

    self._reset_hovered = UI.drawButton(
        "RESET", btn_start_x + (btn_w + btn_gap) * 2, btn_row_y, btn_w, btn_h,
        { font = Fonts.get(18), color = UI.colors.red, hover_color = { 0.95, 0.30, 0.30, 1 } }
    )
end

function SettingsState:drawKeybindsView(W, H)
    local panel_w, panel_h = 440, 458
    local px = (W - panel_w) / 2
    local py = (H - panel_h) / 2

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.purple, border_width = 2 })

    love.graphics.setFont(Fonts.get(28))
    UI.setColor(UI.colors.purple)
    love.graphics.printf("KEYBINDS", px, py + 14, panel_w, "center")

    local content_x = px + 24
    local content_w = panel_w - 48
    local row_y = py + 58
    local row_h = 38

    local mx, my = love.mouse.getPosition()
    self._keybind_buttons = {}

    for i, action in ipairs(keybind_actions) do
        local y = row_y + (i - 1) * row_h
        local current_key = Settings.get(action.setting)
        local is_listening = (listening_action == action.setting)

        love.graphics.setFont(Fonts.get(15))
        UI.setColor(UI.colors.text)
        love.graphics.print(action.label, content_x, y + 8)

        local badge_w = 90
        local badge_h = 28
        local badge_x = content_x + content_w - badge_w
        local badge_y = y + 4
        local badge_hovered = UI.pointInRect(mx, my, badge_x, badge_y, badge_w, badge_h)

        if is_listening then
            local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 5)
            love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.3 * pulse)
            UI.roundRect("fill", badge_x - 2, badge_y - 2, badge_w + 4, badge_h + 4, 6)
            UI.setColor(UI.colors.accent)
            UI.roundRect("fill", badge_x, badge_y, badge_w, badge_h, 4)
            love.graphics.setColor(0.06, 0.06, 0.12, 1)
            love.graphics.setFont(Fonts.get(13))
            love.graphics.printf("...", badge_x, badge_y + 6, badge_w, "center")
        else
            if badge_hovered then
                UI.setColor(UI.colors.panel_hover)
            else
                UI.setColor(UI.colors.panel_light)
            end
            UI.roundRect("fill", badge_x, badge_y, badge_w, badge_h, 4)

            love.graphics.setFont(Fonts.get(14))
            if badge_hovered then
                UI.setColor(UI.colors.text)
            else
                UI.setColor(UI.colors.accent)
            end
            love.graphics.printf(Settings.getKeyName(current_key), badge_x, badge_y + 5, badge_w, "center")
        end

        self._keybind_buttons[i] = {
            x = badge_x, y = badge_y, w = badge_w, h = badge_h,
            hovered = badge_hovered, setting = action.setting,
        }

        if i < #keybind_actions then
            love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], 0.3)
            love.graphics.line(content_x, y + row_h - 1, content_x + content_w, y + row_h - 1)
        end
    end

    local btn_w, btn_h = 140, 44
    local btn_gap = 20
    local btn_row_y = py + panel_h - 62

    self._kb_back_hovered = UI.drawButton(
        "BACK", px + panel_w / 2 - btn_w - btn_gap / 2, btn_row_y, btn_w, btn_h,
        { font = Fonts.get(20), color = UI.colors.blue }
    )

    self._kb_reset_hovered = UI.drawButton(
        "RESET KEYS", px + panel_w / 2 + btn_gap / 2, btn_row_y, btn_w, btn_h,
        { font = Fonts.get(16), color = UI.colors.red, hover_color = { 0.95, 0.30, 0.30, 1 } }
    )
end

function SettingsState:update(dt)
    if dragging and sub_view == "main" then
        local mx = love.mouse.getX()
        local slider = dragging
        local val = (mx - slider.track_x) / slider.track_w
        val = math.max(0, math.min(1, val))
        Settings.set(slider.key, val)
    end
end

function SettingsState:mousepressed(x, y, button)
    if button ~= 1 then return nil end

    if sub_view == "keybinds" then
        return self:mouseKeybindsView(x, y)
    end

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
            if toggle.key == "fullscreen" then
                love.window.setFullscreen(Settings.get("fullscreen"))
            end
            return nil
        end
    end

    if self._back_hovered then
        Settings.save()
        return "settings_back"
    end

    if self._keybinds_hovered then
        sub_view = "keybinds"
        listening_action = nil
        return nil
    end

    if self._reset_hovered then
        Settings.reset()
        return nil
    end

    return nil
end

function SettingsState:mouseKeybindsView(x, y)
    if listening_action then
        listening_action = nil
        return nil
    end

    for _, btn in ipairs(self._keybind_buttons or {}) do
        if btn.hovered then
            listening_action = btn.setting
            return nil
        end
    end

    if self._kb_back_hovered then
        Settings.save()
        sub_view = "main"
        listening_action = nil
        return nil
    end

    if self._kb_reset_hovered then
        Settings.resetKeybinds()
        listening_action = nil
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
    if sub_view == "keybinds" then
        if listening_action then
            if key == "escape" then
                listening_action = nil
            else
                Settings.set(listening_action, key)
                Settings.save()
                listening_action = nil
            end
            return nil
        end
        if key == "escape" then
            Settings.save()
            sub_view = "main"
            return nil
        end
        return nil
    end

    if key == "escape" then
        Settings.save()
        return "settings_back"
    end
    return nil
end

return SettingsState
