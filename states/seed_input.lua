local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local RNG = require("functions/rng")

local SeedInput = {}

local input_text = ""
local cursor_blink = 0
local placeholder = "Leave empty for random seed"

function SeedInput:init()
    input_text = ""
    cursor_blink = 0
    love.keyboard.setKeyRepeat(true)
end

function SeedInput:cleanup()
    love.keyboard.setKeyRepeat(false)
end

function SeedInput:update(dt)
    cursor_blink = cursor_blink + dt
end

function SeedInput:draw()
    local W, H = love.graphics.getDimensions()

    UI.setColor(UI.colors.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(Fonts.get(36))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("ENTER SEED", 0, H * 0.18, W, "center")

    love.graphics.setFont(Fonts.get(16))
    UI.setColor(UI.colors.text_dim)
    love.graphics.printf("Same seed = same run. Share seeds with friends!", 0, H * 0.18 + 50, W, "center")

    local box_w, box_h = 400, 52
    local box_x = (W - box_w) / 2
    local box_y = H * 0.40

    UI.drawPanel(box_x, box_y, box_w, box_h, { border = UI.colors.accent, border_width = 2 })

    love.graphics.setFont(Fonts.get(24))
    if #input_text > 0 then
        UI.setColor(UI.colors.text)
        love.graphics.printf(input_text, box_x + 16, box_y + (box_h - Fonts.get(24):getHeight()) / 2, box_w - 32, "left")
    else
        UI.setColor(UI.colors.text_dark)
        love.graphics.printf(placeholder, box_x + 16, box_y + (box_h - Fonts.get(24):getHeight()) / 2, box_w - 32, "left")
    end

    if math.floor(cursor_blink * 2) % 2 == 0 then
        local text_w = Fonts.get(24):getWidth(input_text)
        UI.setColor(UI.colors.text)
        local cx = box_x + 16 + text_w
        local cy = box_y + 10
        love.graphics.rectangle("fill", cx, cy, 2, box_h - 20)
    end

    local btn_w, btn_h = 260, 52
    local btn_x = (W - btn_w) / 2
    local btn_y = H * 0.55

    local start_label = #input_text > 0 and ("START: " .. input_text:upper()) or "START (RANDOM SEED)"
    self._start_hovered = UI.drawButton(
        start_label, btn_x, btn_y, btn_w, btn_h,
        { font = Fonts.get(20), color = UI.colors.green, hover_color = { 0.25, 0.85, 0.45, 1 } }
    )

    self._back_hovered = UI.drawButton(
        "BACK", btn_x, btn_y + 66, btn_w, btn_h,
        { font = Fonts.get(20), color = UI.colors.red, hover_color = { 0.95, 0.30, 0.30, 1 } }
    )

    love.graphics.setFont(Fonts.get(13))
    UI.setColor(UI.colors.text_dark)
    love.graphics.printf("Alphanumeric characters only (A-Z, 0-9)", 0, H * 0.40 + 60, W, "center")
end

function SeedInput:getSeed()
    if #input_text > 0 then
        return input_text:upper()
    else
        return RNG.generateSeed()
    end
end

function SeedInput:mousepressed(x, y, button)
    if button ~= 1 then return nil end
    if self._start_hovered then
        self:cleanup()
        return "confirm_seed"
    elseif self._back_hovered then
        self:cleanup()
        return "back_to_menu"
    end
    return nil
end

function SeedInput:keypressed(key)
    if key == "return" then
        self:cleanup()
        return "confirm_seed"
    elseif key == "escape" then
        self:cleanup()
        return "back_to_menu"
    elseif key == "backspace" then
        input_text = input_text:sub(1, -2)
    end
    return nil
end

function SeedInput:textinput(text)
    local filtered = text:upper():gsub("[^A-Z0-9]", "")
    if #input_text + #filtered <= 16 then
        input_text = input_text .. filtered
    end
end

return SeedInput
