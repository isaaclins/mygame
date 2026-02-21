local Fonts = require("functions/fonts")

local Toast = {}

local active_toasts = {}
local toast_id = 0

local TOAST_DURATION = 2.5
local SLIDE_SPEED = 12
local FADE_SPEED = 4

local type_colors = {
    success = { 0.20, 0.78, 0.40, 1 },
    error   = { 0.90, 0.22, 0.22, 1 },
    info    = { 1.00, 0.84, 0.00, 1 },
    neutral = { 0.55, 0.55, 0.65, 1 },
}

function Toast.show(text, toast_type)
    toast_id = toast_id + 1
    table.insert(active_toasts, {
        id = toast_id,
        text = text,
        toast_type = toast_type or "info",
        timer = TOAST_DURATION,
        y_off = 40,
        alpha = 0,
        phase = "in",
    })
end

function Toast.success(text) Toast.show(text, "success") end
function Toast.error(text) Toast.show(text, "error") end
function Toast.info(text) Toast.show(text, "info") end

function Toast.update(dt)
    local i = 1
    while i <= #active_toasts do
        local t = active_toasts[i]
        t.timer = t.timer - dt

        if t.phase == "in" then
            t.alpha = math.min(1, t.alpha + dt * FADE_SPEED)
            t.y_off = t.y_off * math.max(0, 1 - dt * SLIDE_SPEED)
            if t.alpha >= 0.99 then t.phase = "hold" end
        elseif t.phase == "hold" then
            if t.timer <= 0.4 then t.phase = "out" end
        elseif t.phase == "out" then
            t.alpha = math.max(0, t.alpha - dt * FADE_SPEED)
            t.y_off = t.y_off + dt * 60
            if t.alpha <= 0 then
                table.remove(active_toasts, i)
                i = i - 1
            end
        end

        i = i + 1
    end
end

function Toast.draw()
    if #active_toasts == 0 then return end

    local W, H = love.graphics.getDimensions()
    local font = Fonts.get(16)
    local toast_h = font:getHeight() + 16

    for idx, t in ipairs(active_toasts) do
        local stack_offset = (idx - 1) * (toast_h + 6)
        local toast_w = math.min(500, font:getWidth(t.text) + 40)
        local tx = (W - toast_w) / 2
        local ty = H - 90 - stack_offset + t.y_off

        local accent = type_colors[t.toast_type] or type_colors.info

        love.graphics.setColor(0.08, 0.08, 0.15, 0.92 * t.alpha)
        love.graphics.rectangle("fill", tx, ty, toast_w, toast_h, 6, 6)

        love.graphics.setColor(accent[1], accent[2], accent[3], t.alpha)
        love.graphics.rectangle("fill", tx, ty, 4, toast_h, 3, 3)

        love.graphics.setColor(accent[1], accent[2], accent[3], 0.08 * t.alpha)
        love.graphics.rectangle("fill", tx, ty, toast_w, toast_h, 6, 6)

        love.graphics.setColor(1, 1, 1, t.alpha)
        love.graphics.setFont(font)
        love.graphics.printf(t.text, tx + 14, ty + 8, toast_w - 28, "center")
    end
end

function Toast.clear()
    active_toasts = {}
end

return Toast
