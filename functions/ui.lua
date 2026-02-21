local UI = {}

UI.colors = {
    bg           = { 0.06, 0.06, 0.12, 1 },
    panel        = { 0.11, 0.11, 0.20, 1 },
    panel_light  = { 0.16, 0.16, 0.28, 1 },
    panel_hover  = { 0.20, 0.20, 0.34, 1 },
    accent       = { 1.00, 0.84, 0.00, 1 },
    accent_dim   = { 0.80, 0.65, 0.00, 1 },
    accent_soft  = { 1.00, 0.92, 0.55, 1 },
    gold_glow    = { 1.00, 0.90, 0.40, 0.35 },
    green        = { 0.20, 0.78, 0.40, 1 },
    green_light  = { 0.30, 0.90, 0.50, 1 },
    red          = { 0.90, 0.22, 0.22, 1 },
    red_flash    = { 1.00, 0.30, 0.30, 0.6 },
    blue         = { 0.30, 0.50, 0.90, 1 },
    blue_hover   = { 0.40, 0.60, 1.00, 1 },
    purple       = { 0.58, 0.30, 0.85, 1 },
    purple_dim   = { 0.40, 0.20, 0.60, 1 },
    orange       = { 0.95, 0.60, 0.15, 1 },
    orange_dim   = { 0.75, 0.45, 0.10, 1 },
    text         = { 1.00, 1.00, 1.00, 1 },
    text_dim     = { 0.55, 0.55, 0.65, 1 },
    text_dark    = { 0.30, 0.30, 0.40, 1 },
    die_white    = { 0.95, 0.93, 0.88, 1 },
    die_black    = { 0.15, 0.15, 0.15, 1 },
    die_blue     = { 0.20, 0.40, 0.85, 1 },
    die_green    = { 0.15, 0.65, 0.30, 1 },
    die_red      = { 0.85, 0.20, 0.20, 1 },
    locked_tint  = { 0.85, 0.15, 0.15, 0.35 },
    free_badge   = { 0.15, 0.75, 0.30, 1 },
    shadow       = { 0.00, 0.00, 0.00, 0.40 },
}

local dot_positions = {
    [1] = { { 0.5, 0.5 } },
    [2] = { { 0.27, 0.27 }, { 0.73, 0.73 } },
    [3] = { { 0.27, 0.27 }, { 0.5, 0.5 }, { 0.73, 0.73 } },
    [4] = { { 0.27, 0.27 }, { 0.73, 0.27 }, { 0.27, 0.73 }, { 0.73, 0.73 } },
    [5] = { { 0.27, 0.27 }, { 0.73, 0.27 }, { 0.5, 0.5 }, { 0.27, 0.73 }, { 0.73, 0.73 } },
    [6] = { { 0.27, 0.27 }, { 0.73, 0.27 }, { 0.27, 0.5 }, { 0.73, 0.5 }, { 0.27, 0.73 }, { 0.73, 0.73 } },
}

local button_anim = {}

function UI.setColor(c)
    love.graphics.setColor(c[1], c[2], c[3], c[4] or 1)
end

function UI.lerpColor(a, b, t)
    return {
        a[1] + (b[1] - a[1]) * t,
        a[2] + (b[2] - a[2]) * t,
        a[3] + (b[3] - a[3]) * t,
        (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t,
    }
end

function UI.roundRect(mode, x, y, w, h, r)
    love.graphics.rectangle(mode, x, y, w, h, r, r)
end

function UI.drawShadow(x, y, w, h, r, offset)
    offset = offset or 4
    love.graphics.setColor(0, 0, 0, 0.25)
    UI.roundRect("fill", x + offset + 2, y + offset + 2, w, h, r or 8)
    love.graphics.setColor(0, 0, 0, 0.40)
    UI.roundRect("fill", x + offset, y + offset, w, h, r or 8)
end

function UI.drawButton(text, x, y, w, h, opts)
    opts = opts or {}
    local mx, my = love.mouse.getPosition()
    local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
    local r = opts.radius or 8
    local font = opts.font or love.graphics.getFont()

    local btn_key = text .. tostring(x) .. tostring(y)
    if not button_anim[btn_key] then
        button_anim[btn_key] = { scale = 1, hover_t = 0 }
    end
    local ba = button_anim[btn_key]

    local target_hover = (hovered and not opts.disabled) and 1 or 0
    ba.hover_t = ba.hover_t + (target_hover - ba.hover_t) * math.min(1, 12 * (love.timer.getDelta()))

    local target_scale = 1.0
    if opts.disabled then
        target_scale = 1.0
    elseif hovered and love.mouse.isDown(1) then
        target_scale = 0.97
    elseif hovered then
        target_scale = 1.04
    end
    ba.scale = ba.scale + (target_scale - ba.scale) * math.min(1, 14 * (love.timer.getDelta()))

    local cx = x + w / 2
    local cy = y + h / 2
    local sw = w * ba.scale
    local sh = h * ba.scale
    local sx = cx - sw / 2
    local sy = cy - sh / 2

    UI.drawShadow(sx, sy, sw, sh, r)

    local base_color = opts.color or UI.colors.blue
    local hover_color = opts.hover_color or UI.colors.blue_hover
    if opts.disabled then
        UI.setColor(UI.colors.panel)
    else
        UI.setColor(UI.lerpColor(base_color, hover_color, ba.hover_t))
    end
    UI.roundRect("fill", sx, sy, sw, sh, r)

    love.graphics.setColor(1, 1, 1, 0.06 * ba.hover_t)
    UI.roundRect("fill", sx, sy, sw, sh * 0.5, r)

    if opts.disabled then
        UI.setColor(UI.colors.text_dark)
    else
        UI.setColor(opts.text_color or UI.colors.text)
    end
    local prev_font = love.graphics.getFont()
    love.graphics.setFont(font)
    love.graphics.printf(text, sx, sy + (sh - font:getHeight()) / 2, sw, "center")
    love.graphics.setFont(prev_font)

    return hovered
end

function UI.drawDie(x, y, size, value, dot_color, body_color, locked, hovered, special_glow)
    local r = size * 0.15

    UI.drawShadow(x, y, size, size, r, 3)

    UI.setColor(body_color or UI.colors.die_white)
    UI.roundRect("fill", x, y, size, size, r)

    love.graphics.setColor(0, 0, 0, 0.08)
    UI.roundRect("fill", x + 2, y + size * 0.55, size - 4, size * 0.43, r * 0.6)

    love.graphics.setColor(1, 1, 1, 0.10)
    UI.roundRect("fill", x + 2, y + 2, size - 4, size * 0.35, r)

    if special_glow then
        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(special_glow[1], special_glow[2], special_glow[3], (special_glow[4] or 1) * 0.5)
        UI.roundRect("line", x - 2, y - 2, size + 4, size + 4, r)
        love.graphics.setLineWidth(2)
        UI.setColor(special_glow)
        UI.roundRect("line", x - 1, y - 1, size + 2, size + 2, r)
        love.graphics.setLineWidth(1)
    end

    if hovered and not locked then
        love.graphics.setColor(1, 1, 1, 0.12)
        UI.roundRect("fill", x, y, size, size, r)
    end

    local dot_r = size * 0.085
    local positions = dot_positions[value] or dot_positions[1]
    for _, pos in ipairs(positions) do
        local dx = x + pos[1] * size
        local dy = y + pos[2] * size
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.circle("fill", dx + 1, dy + 1, dot_r)
        UI.setColor(dot_color or UI.colors.die_black)
        love.graphics.circle("fill", dx, dy, dot_r)
    end

    if locked then
        love.graphics.setColor(0, 0, 0, 0.18)
        UI.roundRect("fill", x, y, size, size, r)

        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(0.9, 0.2, 0.2, 0.7)
        UI.roundRect("line", x, y, size, size, r)
        love.graphics.setLineWidth(1)

        local badge_r = math.max(8, size * 0.14)
        local badge_x = x + size - badge_r * 0.6
        local badge_y = y - badge_r * 0.4

        love.graphics.setColor(0.85, 0.15, 0.15, 0.95)
        love.graphics.circle("fill", badge_x, badge_y, badge_r)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.circle("fill", badge_x, badge_y, badge_r - 1.5)
        love.graphics.setColor(0.85, 0.15, 0.15, 0.95)
        love.graphics.circle("fill", badge_x, badge_y, badge_r - 3)

        local lw = badge_r * 0.55
        local lh = badge_r * 0.45
        local lbx = badge_x - lw / 2
        local lby = badge_y - lh * 0.15
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.rectangle("fill", lbx, lby, lw, lh, 1.5, 1.5)
        local shackle_r = lw * 0.32
        love.graphics.setLineWidth(math.max(1.5, badge_r * 0.12))
        love.graphics.arc("line", "open", badge_x, lby, shackle_r, math.pi, 0)
        love.graphics.setLineWidth(1)
    end
end

function UI.drawPanel(x, y, w, h, opts)
    opts = opts or {}
    local r = opts.radius or 10

    UI.drawShadow(x, y, w, h, r)
    UI.setColor(opts.color or UI.colors.panel)
    UI.roundRect("fill", x, y, w, h, r)

    love.graphics.setColor(1, 1, 1, 0.04)
    UI.roundRect("fill", x + 1, y + 1, w - 2, 2, r)

    if opts.border then
        love.graphics.setLineWidth(opts.border_width or 2)
        UI.setColor(opts.border)
        UI.roundRect("line", x, y, w, h, r)
        love.graphics.setLineWidth(1)
    end
end

function UI.pointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function UI.drawBadge(text, x, y, color, font, pulse)
    font = font or love.graphics.getFont()
    local tw = font:getWidth(text) + 12
    local th = font:getHeight() + 4

    if pulse then
        local glow_alpha = 0.15 + 0.15 * math.sin(love.timer.getTime() * 4)
        love.graphics.setColor(
            (color or UI.colors.free_badge)[1],
            (color or UI.colors.free_badge)[2],
            (color or UI.colors.free_badge)[3],
            glow_alpha
        )
        UI.roundRect("fill", x - 3, y - 3, tw + 6, th + 6, 7)
    end

    UI.setColor(color or UI.colors.free_badge)
    UI.roundRect("fill", x, y, tw, th, 4)
    UI.setColor(UI.colors.text)
    local prev = love.graphics.getFont()
    love.graphics.setFont(font)
    love.graphics.printf(text, x, y + 2, tw, "center")
    love.graphics.setFont(prev)
    return tw
end

function UI.drawGlow(x, y, w, h, color, intensity)
    intensity = intensity or 0.3
    local c = color or UI.colors.accent
    for i = 3, 1, -1 do
        local a = intensity * (1 - (i - 1) / 3)
        love.graphics.setColor(c[1], c[2], c[3], a)
        UI.roundRect("fill", x - i * 4, y - i * 4, w + i * 8, h + i * 8, 12 + i * 2)
    end
end

function UI.drawVignette()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(0, 0, 0, 0.25)
    love.graphics.circle("fill", w / 2, h / 2, math.max(w, h) * 0.6)
end

function UI.lerp(a, b, t)
    return a + (b - a) * t
end

function UI.clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

function UI.resetButtonAnims()
    button_anim = {}
end

return UI
