local Tween = {}

local active = {}
local id_counter = 0

local easing = {}

function easing.linear(t) return t end

function easing.inQuad(t) return t * t end
function easing.outQuad(t) return t * (2 - t) end
function easing.inOutQuad(t)
    if t < 0.5 then return 2 * t * t end
    return -1 + (4 - 2 * t) * t
end

function easing.inCubic(t) return t * t * t end
function easing.outCubic(t) local u = t - 1; return u * u * u + 1 end
function easing.inOutCubic(t)
    if t < 0.5 then return 4 * t * t * t end
    local u = 2 * t - 2; return 0.5 * u * u * u + 1
end

function easing.outBack(t)
    local s = 1.70158
    local u = t - 1
    return u * u * ((s + 1) * u + s) + 1
end

function easing.inBack(t)
    local s = 1.70158
    return t * t * ((s + 1) * t - s)
end

function easing.outElastic(t)
    if t == 0 or t == 1 then return t end
    return math.pow(2, -10 * t) * math.sin((t - 0.075) * (2 * math.pi) / 0.3) + 1
end

function easing.inElastic(t)
    if t == 0 or t == 1 then return t end
    return -math.pow(2, 10 * (t - 1)) * math.sin((t - 1.075) * (2 * math.pi) / 0.3)
end

function easing.outBounce(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end
end

function easing.inExpo(t)
    if t == 0 then return 0 end
    return math.pow(2, 10 * (t - 1))
end

function easing.outExpo(t)
    if t == 1 then return 1 end
    return 1 - math.pow(2, -10 * t)
end

Tween.easing = easing

function Tween.to(target, duration, props, ease_name, on_complete)
    id_counter = id_counter + 1
    local ease_fn = easing[ease_name or "outCubic"] or easing.outCubic
    local start_vals = {}
    local end_vals = {}
    for k, v in pairs(props) do
        start_vals[k] = target[k] or 0
        end_vals[k] = v
    end
    local tw = {
        id = id_counter,
        target = target,
        duration = duration,
        elapsed = 0,
        ease = ease_fn,
        start_vals = start_vals,
        end_vals = end_vals,
        on_complete = on_complete,
        cancelled = false,
    }
    table.insert(active, tw)
    return tw
end

function Tween.cancel(tw)
    if tw then tw.cancelled = true end
end

function Tween.cancelAll(target)
    for _, tw in ipairs(active) do
        if tw.target == target then tw.cancelled = true end
    end
end

function Tween.update(dt)
    local i = 1
    while i <= #active do
        local tw = active[i]
        if tw.cancelled then
            table.remove(active, i)
        else
            tw.elapsed = tw.elapsed + dt
            local t = math.min(tw.elapsed / tw.duration, 1)
            local eased = tw.ease(t)
            for k, _ in pairs(tw.end_vals) do
                tw.target[k] = tw.start_vals[k] + (tw.end_vals[k] - tw.start_vals[k]) * eased
            end
            if t >= 1 then
                if tw.on_complete then tw.on_complete() end
                table.remove(active, i)
            else
                i = i + 1
            end
        end
    end
end

function Tween.reset()
    active = {}
end

function Tween.lerp(a, b, t)
    return a + (b - a) * t
end

function Tween.smoothDamp(current, target, speed, dt)
    return current + (target - current) * math.min(1, speed * dt)
end

return Tween
