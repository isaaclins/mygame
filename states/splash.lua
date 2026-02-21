local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local SaveLoad = require("functions/saveload")
local Tween = require("functions/tween")

local Splash = {}

local time_elapsed = 0
local floating_dice = {}
local has_save = false
local mouse_x, mouse_y = 0, 0

local title_anim = { scale = 1.0, alpha = 0, y_off = 0 }
local subtitle_anim = { alpha = 0, chars = 0 }
local button_anims = {}
local footer_anim = { alpha = 0 }
local title_glow_time = 0
local subtitle_text = "A Yahtzee Roguelike"

local function spawnDie(W, H, start_above)
    local depth = 0.3 + math.random() * 0.7
    local size = math.floor(22 + depth * 42)
    return {
        x = math.random(size, W - size),
        y = start_above and math.random(-H, -size) or math.random(-size, H),
        value = math.random(1, 6),
        size = size,
        fall_speed = 30 + depth * 70,
        sway_speed = 0.4 + math.random() * 0.8,
        sway_amount = 15 + math.random() * 25,
        phase = math.random() * math.pi * 2,
        alpha = 1,
        depth = depth,
        rot = math.random() * math.pi * 2,
        rot_speed = (math.random() - 0.5) * 0.6,
    }
end

function Splash:init()
    time_elapsed = 0
    has_save = SaveLoad.hasSave()
    floating_dice = {}
    mouse_x, mouse_y = love.mouse.getPosition()

    local W, H = love.graphics.getDimensions()
    for i = 1, 30 do
        table.insert(floating_dice, spawnDie(W, H, false))
    end

    title_anim = { scale = 1.15, alpha = 0, y_off = -30 }
    Tween.to(title_anim, 0.8, { scale = 1.0, alpha = 1, y_off = 0 }, "outBack")

    subtitle_anim = { alpha = 0, chars = 0 }
    Tween.to(subtitle_anim, 0.6, { alpha = 1 }, "outCubic")
    Tween.to(subtitle_anim, 1.2, { chars = #subtitle_text }, "outCubic")

    button_anims = {}
    local btn_count = has_save and 4 or 3
    for i = 1, btn_count do
        local ba = { alpha = 0, y_off = 30 }
        button_anims[i] = ba
        Tween.to(ba, 0.5, { alpha = 1, y_off = 0 }, "outBack")
    end

    footer_anim = { alpha = 0 }
    Tween.to(footer_anim, 0.8, { alpha = 1 }, "outCubic")

    title_glow_time = 0
end

function Splash:update(dt)
    time_elapsed = time_elapsed + dt
    title_glow_time = title_glow_time + dt
    mouse_x, mouse_y = love.mouse.getPosition()

    local W, H = love.graphics.getDimensions()

    for i, d in ipairs(floating_dice) do
        d.y = d.y + d.fall_speed * dt
        d.phase = d.phase + dt * d.sway_speed
        d.rot = d.rot + dt * d.rot_speed

        if d.y > H + d.size + 20 then
            floating_dice[i] = spawnDie(W, H, true)
        end
    end
end

function Splash:draw()
    local W, H = love.graphics.getDimensions()

    UI.setColor(UI.colors.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local dot_positions = {
        [1] = { { 0.5, 0.5 } },
        [2] = { { 0.27, 0.27 }, { 0.73, 0.73 } },
        [3] = { { 0.27, 0.27 }, { 0.5, 0.5 }, { 0.73, 0.73 } },
        [4] = { { 0.27, 0.27 }, { 0.73, 0.27 }, { 0.27, 0.73 }, { 0.73, 0.73 } },
        [5] = { { 0.27, 0.27 }, { 0.73, 0.27 }, { 0.5, 0.5 }, { 0.27, 0.73 }, { 0.73, 0.73 } },
        [6] = { { 0.27, 0.27 }, { 0.73, 0.27 }, { 0.27, 0.5 }, { 0.73, 0.5 }, { 0.27, 0.73 }, { 0.73, 0.73 } },
    }

    for _, d in ipairs(floating_dice) do
        local sx = d.x + math.sin(d.phase) * d.sway_amount
        love.graphics.push()
        love.graphics.translate(sx + d.size / 2, d.y + d.size / 2)
        love.graphics.rotate(d.rot)

        local r = d.size * 0.15
        love.graphics.setColor(0.95, 0.93, 0.88, d.alpha)
        UI.roundRect("fill", -d.size / 2, -d.size / 2, d.size, d.size, r)

        local dot_r = d.size * 0.075
        local positions = dot_positions[d.value]
        love.graphics.setColor(0.2, 0.2, 0.2, d.alpha * 0.9)
        for _, pos in ipairs(positions) do
            local dx = -d.size / 2 + pos[1] * d.size
            local dy = -d.size / 2 + pos[2] * d.size
            love.graphics.circle("fill", dx, dy, dot_r)
        end

        love.graphics.pop()
    end

    local title_y = H * 0.18 + title_anim.y_off + math.sin(title_glow_time * 1.2) * 4
    local title_scale = title_anim.scale + math.sin(title_glow_time * 0.8) * 0.01

    love.graphics.push()
    love.graphics.translate(W / 2, title_y + 32)
    love.graphics.scale(title_scale, title_scale)

    love.graphics.setFont(Fonts.get(64))
    local glow_alpha = (0.12 + 0.06 * math.sin(title_glow_time * 2)) * title_anim.alpha
    love.graphics.setColor(1.0, 0.84, 0, glow_alpha)
    for dx = -3, 3 do
        for dy = -3, 3 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.printf("DICE x BALATRO", dx - W / 2, dy - 32, W, "center")
            end
        end
    end

    love.graphics.setColor(1.0, 0.84, 0, title_anim.alpha)
    love.graphics.printf("DICE x BALATRO", -W / 2, -32, W, "center")
    love.graphics.pop()

    love.graphics.setFont(Fonts.get(22))
    local visible = math.floor(subtitle_anim.chars)
    local partial = subtitle_text:sub(1, visible)
    love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], subtitle_anim.alpha)
    love.graphics.printf(partial, 0, title_y + 80, W, "center")

    local btn_w, btn_h = 260, 56
    local btn_x = (W - btn_w) / 2
    local btn_y = H * 0.46

    local btn_idx = 1
    if has_save then
        local ba = button_anims[btn_idx] or { alpha = 1, y_off = 0 }
        love.graphics.setColor(1, 1, 1, ba.alpha)
        self._continue_hovered = UI.drawButton(
            "CONTINUE", btn_x, btn_y + ba.y_off, btn_w, btn_h,
            { font = Fonts.get(26), color = UI.colors.accent, hover_color = { 1.0, 0.90, 0.20, 1 } }
        )
        btn_y = btn_y + 68
        btn_idx = btn_idx + 1
    else
        self._continue_hovered = false
    end

    local ba = button_anims[btn_idx] or { alpha = 1, y_off = 0 }
    self._new_game_hovered = UI.drawButton(
        "NEW GAME", btn_x, btn_y + ba.y_off, btn_w, btn_h,
        { font = Fonts.get(26), color = UI.colors.green, hover_color = UI.colors.green_light }
    )
    btn_idx = btn_idx + 1

    ba = button_anims[btn_idx] or { alpha = 1, y_off = 0 }
    self._settings_hovered = UI.drawButton(
        "SETTINGS", btn_x, btn_y + 68 + ba.y_off, btn_w, btn_h,
        { font = Fonts.get(26), color = UI.colors.panel_light, hover_color = UI.colors.panel_hover }
    )
    btn_idx = btn_idx + 1

    ba = button_anims[btn_idx] or { alpha = 1, y_off = 0 }
    self._exit_hovered = UI.drawButton(
        "EXIT", btn_x, btn_y + 136 + ba.y_off, btn_w, btn_h,
        { font = Fonts.get(26), color = UI.colors.red, hover_color = { 0.95, 0.30, 0.30, 1 } }
    )

    love.graphics.setFont(Fonts.get(14))
    love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], footer_anim.alpha)
    love.graphics.printf("Roll. Lock. Score. Survive.", 0, H - 40, W, "center")
end

function Splash:mousepressed(x, y, button)
    if button == 1 then
        if self._continue_hovered then
            return "continue_game"
        elseif self._new_game_hovered then
            return "start_game"
        elseif self._settings_hovered then
            return "open_settings"
        elseif self._exit_hovered then
            return "exit"
        end
    end
    return nil
end

function Splash:keypressed(key)
    if key == "return" or key == "space" then
        if has_save then
            return "continue_game"
        end
        return "start_game"
    elseif key == "escape" then
        return "exit"
    end
    return nil
end

return Splash
