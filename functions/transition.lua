local Transition = {}

local state = "none"
local alpha = 0
local duration = 0.3
local timer = 0
local callback = nil

function Transition.fadeTo(fn, dur)
    if state ~= "none" then return end
    state = "fade_out"
    duration = dur or 0.3
    timer = 0
    callback = fn
end

function Transition.update(dt)
    if state == "none" then return end

    timer = timer + dt

    if state == "fade_out" then
        alpha = math.min(1, timer / duration)
        if alpha >= 1 then
            if callback then callback() end
            callback = nil
            state = "fade_in"
            timer = 0
        end
    elseif state == "fade_in" then
        alpha = 1 - math.min(1, timer / duration)
        if alpha <= 0 then
            alpha = 0
            state = "none"
        end
    end
end

function Transition.draw()
    if state == "none" or alpha <= 0 then return end
    love.graphics.setColor(0.04, 0.04, 0.08, alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    love.graphics.setColor(1, 1, 1, 1)
end

function Transition.isActive()
    return state ~= "none"
end

return Transition
