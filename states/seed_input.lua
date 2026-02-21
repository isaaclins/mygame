local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local RNG = require("functions/rng")
local Tween = require("functions/tween")

local SeedInput = {}

local input_text = ""
local cursor_blink = 0
local placeholder = "Leave empty for random seed"
local input_pop = { scale = 1 }
local title_anim = { alpha = 0, y_off = -20 }
local start_glow = 0

function SeedInput:init()
    input_text = ""
    cursor_blink = 0
    input_pop = { scale = 1 }
    start_glow = 0
    love.keyboard.setKeyRepeat(true)

    title_anim = { alpha = 0, y_off = -20 }
    Tween.to(title_anim, 0.5, { alpha = 1, y_off = 0 }, "outCubic")
end

function SeedInput:cleanup()
    love.keyboard.setKeyRepeat(false)
end

function SeedInput:update(dt)
    cursor_blink = cursor_blink + dt
    input_pop.scale = input_pop.scale + (1.0 - input_pop.scale) * math.min(1, 10 * dt)

    if #input_text > 0 then
        start_glow = math.min(1, start_glow + dt * 3)
    else
        start_glow = math.max(0, start_glow - dt * 3)
    end
end

function SeedInput:draw()
    local W, H = love.graphics.getDimensions()

    UI.setColor(UI.colors.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(Fonts.get(36))
    love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], title_anim.alpha)
    love.graphics.printf("ENTER SEED", 0, H * 0.18 + title_anim.y_off, W, "center")

    love.graphics.setFont(Fonts.get(16))
    love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], title_anim.alpha)
    love.graphics.printf("Same seed = same run. Share seeds with friends!", 0, H * 0.18 + 50 + title_anim.y_off, W, "center")

    local box_w, box_h = 400, 52
    local box_x = (W - box_w) / 2
    local box_y = H * 0.40

    love.graphics.push()
    local bx_cx = box_x + box_w / 2
    local bx_cy = box_y + box_h / 2
    love.graphics.translate(bx_cx, bx_cy)
    love.graphics.scale(input_pop.scale, input_pop.scale)
    love.graphics.translate(-bx_cx, -bx_cy)

    UI.drawPanel(box_x, box_y, box_w, box_h, { border = UI.colors.accent, border_width = 2 })

    love.graphics.setFont(Fonts.get(24))
    if #input_text > 0 then
        UI.setColor(UI.colors.text)
        love.graphics.printf(input_text, box_x + 16, box_y + (box_h - Fonts.get(24):getHeight()) / 2, box_w - 32, "left")
    else
        UI.setColor(UI.colors.text_dark)
        love.graphics.printf(placeholder, box_x + 16, box_y + (box_h - Fonts.get(24):getHeight()) / 2, box_w - 32, "left")
    end

    local cursor_alpha = 0.5 + 0.5 * math.sin(cursor_blink * math.pi * 2)
    local text_w = Fonts.get(24):getWidth(input_text)
    love.graphics.setColor(1, 1, 1, cursor_alpha)
    local cx = box_x + 16 + text_w
    local cy = box_y + 10
    love.graphics.rectangle("fill", cx, cy, 2, box_h - 20)

    love.graphics.pop()

    local btn_w, btn_h = 260, 52
    local btn_x = (W - btn_w) / 2
    local btn_y = H * 0.55

    if start_glow > 0.1 then
        local glow_a = 0.1 + 0.08 * math.sin(love.timer.getTime() * 3)
        love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], glow_a * start_glow)
        UI.roundRect("fill", btn_x - 4, btn_y - 4, btn_w + 8, btn_h + 8, 12)
    end

    local start_label = #input_text > 0 and ("START: " .. input_text:upper()) or "START (RANDOM SEED)"
    self._start_hovered = UI.drawButton(
        start_label, btn_x, btn_y, btn_w, btn_h,
        { font = Fonts.get(20), color = UI.colors.green, hover_color = UI.colors.green_light }
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
        input_pop.scale = 1.06
    end
end

return SeedInput
