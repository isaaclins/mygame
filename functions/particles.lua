local Particles = {}

local emitters = {}

function Particles.emit(opts)
    local e = {
        x = opts.x or 0,
        y = opts.y or 0,
        particles = {},
        timer = 0,
    }
    local count = opts.count or 20
    for i = 1, count do
        local angle = (opts.angle_min or 0) + math.random() * ((opts.angle_max or (math.pi * 2)) - (opts.angle_min or 0))
        local speed = (opts.speed_min or 40) + math.random() * ((opts.speed_max or 120) - (opts.speed_min or 40))
        local life = (opts.life_min or 0.5) + math.random() * ((opts.life_max or 1.2) - (opts.life_min or 0.5))
        local size = (opts.size_min or 2) + math.random() * ((opts.size_max or 5) - (opts.size_min or 2))
        local c = opts.color or { 1, 0.84, 0, 1 }
        table.insert(e.particles, {
            x = e.x + (math.random() - 0.5) * (opts.spread or 0),
            y = e.y + (math.random() - 0.5) * (opts.spread or 0),
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = life,
            max_life = life,
            size = size,
            color = { c[1], c[2], c[3], c[4] or 1 },
            gravity = opts.gravity or 60,
            friction = opts.friction or 0.98,
            shape = opts.shape or "circle",
        })
    end
    table.insert(emitters, e)
    return e
end

function Particles.burst(x, y, color, count)
    Particles.emit({
        x = x, y = y,
        count = count or 24,
        color = color or { 1, 0.84, 0, 1 },
        speed_min = 50, speed_max = 180,
        life_min = 0.4, life_max = 1.0,
        size_min = 2, size_max = 6,
        gravity = 80,
        spread = 10,
    })
end

function Particles.sparkle(x, y, color, count)
    Particles.emit({
        x = x, y = y,
        count = count or 12,
        color = color or { 1, 1, 0.6, 1 },
        speed_min = 15, speed_max = 60,
        life_min = 0.3, life_max = 0.8,
        size_min = 1.5, size_max = 4,
        gravity = -20,
        spread = 20,
        friction = 0.95,
    })
end

function Particles.dust(x, y)
    Particles.emit({
        x = x, y = y,
        count = 6,
        color = { 0.7, 0.7, 0.8, 0.6 },
        speed_min = 10, speed_max = 35,
        life_min = 0.2, life_max = 0.5,
        size_min = 1, size_max = 3,
        gravity = -15,
        spread = 8,
        angle_min = -math.pi, angle_max = 0,
    })
end

function Particles.drift(x, y, w, h, color, count)
    Particles.emit({
        x = x + w / 2, y = y + h / 2,
        count = count or 30,
        color = color or { 0.9, 0.15, 0.15, 0.4 },
        speed_min = 5, speed_max = 20,
        life_min = 2.0, life_max = 4.0,
        size_min = 1, size_max = 3,
        gravity = -5,
        spread = math.max(w, h) / 2,
        friction = 0.99,
    })
end

function Particles.update(dt)
    local i = 1
    while i <= #emitters do
        local e = emitters[i]
        local j = 1
        while j <= #e.particles do
            local p = e.particles[j]
            p.life = p.life - dt
            if p.life <= 0 then
                table.remove(e.particles, j)
            else
                p.vx = p.vx * p.friction
                p.vy = p.vy * p.friction
                p.vy = p.vy + p.gravity * dt
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                j = j + 1
            end
        end
        if #e.particles == 0 then
            table.remove(emitters, i)
        else
            i = i + 1
        end
    end
end

function Particles.draw()
    for _, e in ipairs(emitters) do
        for _, p in ipairs(e.particles) do
            local alpha = (p.life / p.max_life) * (p.color[4] or 1)
            local size = p.size * (0.5 + 0.5 * (p.life / p.max_life))
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
            if p.shape == "rect" then
                love.graphics.rectangle("fill", p.x - size / 2, p.y - size / 2, size, size)
            else
                love.graphics.circle("fill", p.x, p.y, size)
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Particles.clear()
    emitters = {}
end

return Particles
