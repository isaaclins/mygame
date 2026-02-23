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

function UI.abbreviate(n)
    if n ~= n then return "nan" end
    if n == math.huge then return "inf" end
    if n == -math.huge then return "-inf" end
    local abs = math.abs(n)
    local sign = n < 0 and "-" or ""
    if abs >= 1e11 then
        local e = math.floor(math.log10(abs))
        local m = abs / (10 ^ e)
        return sign .. string.format("%.2fe%d", m, e)
    elseif abs >= 1e9 then return sign .. string.format("%.2fB", abs / 1e9)
    elseif abs >= 1e6 then return sign .. string.format("%.2fM", abs / 1e6)
    elseif abs >= 1e3 then return sign .. string.format("%.1fK", abs / 1e3)
    else return tostring(math.floor(n))
    end
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

function UI.drawDie(x, y, size, value, dot_color, body_color, locked, hovered, special_glow, boss_locked)
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

    if locked and boss_locked then
        love.graphics.setColor(0.12, 0.05, 0.18, 0.25)
        UI.roundRect("fill", x, y, size, size, r)

        love.graphics.setLineWidth(2.5)
        love.graphics.setColor(0.58, 0.30, 0.85, 0.8)
        UI.roundRect("line", x, y, size, size, r)
        love.graphics.setLineWidth(1)

        local Fonts = require("functions/fonts")
        local prev_font = love.graphics.getFont()
        local q_font_size = math.floor(size * 0.55)
        local q_font = Fonts.get(q_font_size)
        love.graphics.setFont(q_font)

        local q_text = "?"
        local q_w = q_font:getWidth(q_text)
        local q_h = q_font:getHeight()
        local q_x = x + size / 2 - q_w / 2
        local t = love.timer.getTime()
        local bob = math.sin(t * 2.5) * 3
        local q_y = y - q_h - 4 + bob

        for i = 3, 1, -1 do
            local a = 0.12 * (1 - (i - 1) / 3)
            love.graphics.setColor(0.58, 0.30, 0.85, a)
            love.graphics.print(q_text, q_x - i, q_y - i)
            love.graphics.print(q_text, q_x + i, q_y - i)
            love.graphics.print(q_text, q_x - i, q_y + i)
            love.graphics.print(q_text, q_x + i, q_y + i)
        end

        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.print(q_text, q_x + 1, q_y + 1)

        love.graphics.setColor(0.70, 0.40, 0.95, 0.95)
        love.graphics.print(q_text, q_x, q_y)

        love.graphics.setFont(prev_font)
    elseif locked then
        love.graphics.setColor(0.9, 0.10, 0.10, 0.13)
        UI.roundRect("fill", x, y, size, size, r)

        love.graphics.setLineWidth(3)
        love.graphics.setColor(0.9, 0.20, 0.20, 0.80)
        UI.roundRect("line", x, y, size, size, r)
        love.graphics.setLineWidth(1)

        local cx = x + size / 2
        local cy = y + size / 2
        local body_w = size * 0.32
        local body_h = size * 0.24
        local body_x = cx - body_w / 2
        local body_y = cy - body_h / 2 + size * 0.06
        local body_r = math.max(2, size * 0.03)

        local shackle_r = body_w * 0.34
        local shackle_lw = math.max(2.5, size * 0.045)
        love.graphics.setLineWidth(shackle_lw)
        love.graphics.setColor(1, 1, 1, 0.80)
        love.graphics.arc("line", "open", cx, body_y, shackle_r, math.pi, 0)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 1, 1, 0.80)
        love.graphics.rectangle("fill", body_x, body_y, body_w, body_h, body_r, body_r)

        local kh_r = body_h * 0.16
        local kh_cx = cx
        local kh_cy = body_y + body_h * 0.38
        love.graphics.setColor(0.75, 0.15, 0.15, 0.95)
        love.graphics.circle("fill", kh_cx, kh_cy, kh_r)
        love.graphics.rectangle("fill", kh_cx - kh_r * 0.45, kh_cy, kh_r * 0.9, body_h * 0.30)
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

function UI.drawFocusRect(x, y, w, h, r)
    local t = love.timer.getTime()
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    love.graphics.setLineWidth(2.5)
    love.graphics.setColor(1.0, 0.84, 0, 0.6 + 0.3 * pulse)
    UI.roundRect("line", x - 3, y - 3, w + 6, h + 6, (r or 8) + 1)
    love.graphics.setLineWidth(1)
end

function UI.drawSpotlight(hx, hy, hw, hh, dim_alpha, radius)
    dim_alpha = dim_alpha or 0.7
    radius = radius or 10
    local W, H = love.graphics.getDimensions()

    love.graphics.stencil(function()
        UI.roundRect("fill", hx, hy, hw, hh, radius)
    end, "replace", 1)

    love.graphics.setStencilTest("equal", 0)
    love.graphics.setColor(0, 0, 0, dim_alpha)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setStencilTest()

    local t = love.timer.getTime()
    local pulse = 0.5 + 0.5 * math.sin(t * 3)
    love.graphics.setLineWidth(2.5)
    love.graphics.setColor(1.0, 0.84, 0.0, 0.5 + 0.3 * pulse)
    UI.roundRect("line", hx - 2, hy - 2, hw + 4, hh + 4, radius + 1)
    love.graphics.setLineWidth(1)
end

function UI.drawTutorialPanel(x, y, w, title, body, opts)
    opts = opts or {}
    local Fonts = require("functions/fonts")
    local title_font = opts.title_font or Fonts.get(20)
    local body_font = opts.body_font or Fonts.get(15)
    local pad = 14
    local arrow_text = opts.arrow_text or "Click to continue"

    local _, title_wraps = title_font:getWrap(title, w - pad * 2)
    local title_h = #title_wraps * title_font:getHeight()
    local _, body_wraps = body_font:getWrap(body, w - pad * 2)
    local body_h = #body_wraps * body_font:getHeight()

    local arrow_font = Fonts.get(12)
    local arrow_h = arrow_font:getHeight() + 8
    local h = pad + title_h + 8 + body_h + 8 + arrow_h + pad

    UI.drawPanel(x, y, w, h, { border = UI.colors.accent, border_width = 2 })

    love.graphics.setFont(title_font)
    UI.setColor(UI.colors.accent)
    love.graphics.printf(title, x + pad, y + pad, w - pad * 2, "left")

    love.graphics.setFont(body_font)
    UI.setColor(UI.colors.text)
    love.graphics.printf(body, x + pad, y + pad + title_h + 8, w - pad * 2, "left")

    love.graphics.setFont(arrow_font)
    local t = love.timer.getTime()
    local blink = 0.4 + 0.4 * math.sin(t * 3)
    love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], blink)
    love.graphics.printf(arrow_text, x + pad, y + h - pad - arrow_font:getHeight(), w - pad * 2, "right")

    return h
end

return UI
