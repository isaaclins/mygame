local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local RNG = require("functions/rng")
local Tween = require("functions/tween")

local Pause = {}

local panel_anim = { scale = 0.8, alpha = 0 }
local btn_anims = {}
local anim_init = false

local function initAnims()
    panel_anim = { scale = 0.8, alpha = 0 }
    Tween.to(panel_anim, 0.3, { scale = 1.0, alpha = 1 }, "outBack")

    btn_anims = {}
    for i = 1, 4 do
        btn_anims[i] = { alpha = 0, y_off = 15 }
        Tween.to(btn_anims[i], 0.3, { alpha = 1, y_off = 0 }, "outCubic")
    end
    anim_init = true
end

function Pause:draw()
    if not anim_init then initAnims() end

    local W, H = love.graphics.getDimensions()

    love.graphics.setColor(0, 0, 0, 0.55 * panel_anim.alpha)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local panel_w, panel_h = 320, 370
    local px = (W - panel_w) / 2
    local py = (H - panel_h) / 2

    love.graphics.push()
    love.graphics.translate(px + panel_w / 2, py + panel_h / 2)
    love.graphics.scale(panel_anim.scale, panel_anim.scale)
    love.graphics.translate(-(px + panel_w / 2), -(py + panel_h / 2))

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent, border_width = 2 })

    love.graphics.setFont(Fonts.get(36))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("PAUSED", px, py + 24, panel_w, "center")

    local btn_w, btn_h = 220, 48
    local btn_x = px + (panel_w - btn_w) / 2
    local btn_y = py + 84

    local ba1 = btn_anims[1] or { alpha = 1, y_off = 0 }
    self._resume_hovered = UI.drawButton(
        "RESUME", btn_x, btn_y + ba1.y_off, btn_w, btn_h,
        { font = Fonts.get(22), color = UI.colors.green, hover_color = UI.colors.green_light }
    )

    local ba2 = btn_anims[2] or { alpha = 1, y_off = 0 }
    self._settings_hovered = UI.drawButton(
        "SETTINGS", btn_x, btn_y + 60 + ba2.y_off, btn_w, btn_h,
        { font = Fonts.get(22), color = UI.colors.panel_light, hover_color = UI.colors.panel_hover }
    )

    local ba3 = btn_anims[3] or { alpha = 1, y_off = 0 }
    self._menu_hovered = UI.drawButton(
        "SAVE & MENU", btn_x, btn_y + 120 + ba3.y_off, btn_w, btn_h,
        { font = Fonts.get(22), color = UI.colors.blue }
    )

    local ba4 = btn_anims[4] or { alpha = 1, y_off = 0 }
    self._exit_hovered = UI.drawButton(
        "SAVE & EXIT", btn_x, btn_y + 180 + ba4.y_off, btn_w, btn_h,
        { font = Fonts.get(22), color = UI.colors.red, hover_color = { 0.95, 0.30, 0.30, 1 } }
    )

    love.graphics.setFont(Fonts.get(13))
    UI.setColor(UI.colors.text_dark)
    love.graphics.printf("Press Escape to resume", px, py + panel_h - 44, panel_w, "center")

    local seed = RNG.getSeed()
    if #seed > 0 then
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf("Seed: " .. seed, px, py + panel_h - 24, panel_w, "center")
    end

    love.graphics.pop()
end

function Pause:mousepressed(x, y, button)
    if button ~= 1 then return nil end

    if self._resume_hovered then
        anim_init = false
        return "resume"
    elseif self._settings_hovered then
        return "settings"
    elseif self._menu_hovered then
        anim_init = false
        return "save_and_menu"
    elseif self._exit_hovered then
        anim_init = false
        return "save_and_exit"
    end
    return nil
end

function Pause:keypressed(key)
    if key == "escape" then
        anim_init = false
        return "resume"
    end
    return nil
end

return Pause
