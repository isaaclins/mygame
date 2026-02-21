local Class = require("objects/class")
local RNG = require("functions/rng")
local Die = Class:extend()

function Die:init(opts)
    opts = opts or {}
    self.name = opts.name or "Vanilla Die"
    self.color = opts.color or "black"
    self.value = opts.value or 1
    self.locked = false
    self.ability = opts.ability or nil
    self.ability_name = opts.ability_name or "None"
    self.ability_desc = opts.ability_desc or ""
    self.upgrade_level = opts.upgrade_level or 0
    self.max_upgrade = opts.max_upgrade or 3
    self.die_type = opts.die_type or "vanilla"
    self.roll_timer = 0
    self.rolling = false
    self.glow_color = opts.glow_color or nil

    self.weights = opts.weights or { 1, 1, 1, 1, 1, 1 }
end

function Die:roll()
    if self.locked then
        return self.value
    end

    if self.die_type == "wild" then
        self.value = self.wild_choice or RNG.random(1, 6)
        return self.value
    end

    local total = 0
    for _, w in ipairs(self.weights) do
        total = total + w
    end
    local r = RNG.random() * total
    local cumulative = 0
    for i, w in ipairs(self.weights) do
        cumulative = cumulative + w
        if r <= cumulative then
            self.value = i
            break
        end
    end

    if self.die_type == "mirror" then
        self.value = 7 - self.value
    end

    return self.value
end

function Die:startRoll(duration)
    self.rolling = true
    self.roll_timer = duration or 0.5
end

function Die:updateRoll(dt)
    if not self.rolling then return false end
    self.roll_timer = self.roll_timer - dt
    if self.roll_timer <= 0 then
        self.rolling = false
        self:roll()
        return true
    end
    self.value = math.random(1, 6)
    return false
end

function Die:toggleLock()
    self.locked = not self.locked
end

function Die:triggerAbility(context)
    if not self.ability then return nil end
    return self.ability(self, context)
end

function Die:upgrade()
    if self.upgrade_level >= self.max_upgrade then return false end
    self.upgrade_level = self.upgrade_level + 1
    return true
end

function Die:clone()
    return Die:new({
        name = self.name,
        color = self.color,
        ability = self.ability,
        ability_name = self.ability_name,
        ability_desc = self.ability_desc,
        upgrade_level = self.upgrade_level,
        max_upgrade = self.max_upgrade,
        die_type = self.die_type,
        weights = { unpack(self.weights) },
        glow_color = self.glow_color,
    })
end

function Die:getDescription()
    local desc = self.name
    if self.ability_name ~= "None" then
        desc = desc .. " [" .. self.ability_name .. "]"
    end
    if self.upgrade_level > 0 then
        desc = desc .. " +" .. self.upgrade_level
    end
    return desc
end

return Die
