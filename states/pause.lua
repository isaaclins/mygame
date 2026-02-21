local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local RNG = require("functions/rng")

local Pause = {}

function Pause:draw()
    local W, H = love.graphics.getDimensions()

    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local panel_w, panel_h = 320, 300
    local px = (W - panel_w) / 2
    local py = (H - panel_h) / 2

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent, border_width = 2 })

    love.graphics.setFont(Fonts.get(36))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("PAUSED", px, py + 24, panel_w, "center")

    local btn_w, btn_h = 220, 48
    local btn_x = px + (panel_w - btn_w) / 2
    local btn_y = py + 90

    self._resume_hovered = UI.drawButton(
        "RESUME", btn_x, btn_y, btn_w, btn_h,
        { font = Fonts.get(22), color = UI.colors.green, hover_color = { 0.25, 0.85, 0.45, 1 } }
    )

    self._menu_hovered = UI.drawButton(
        "SAVE & MENU", btn_x, btn_y + 64, btn_w, btn_h,
        { font = Fonts.get(22), color = UI.colors.blue }
    )

    self._exit_hovered = UI.drawButton(
        "SAVE & EXIT", btn_x, btn_y + 128, btn_w, btn_h,
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
end

function Pause:mousepressed(x, y, button)
    if button ~= 1 then return nil end

    if self._resume_hovered then
        return "resume"
    elseif self._menu_hovered then
        return "save_and_menu"
    elseif self._exit_hovered then
        return "save_and_exit"
    end
    return nil
end

function Pause:keypressed(key)
    if key == "escape" then
        return "resume"
    end
    return nil
end

return Pause
