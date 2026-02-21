local RNG = {}

local generator = love.math.newRandomGenerator()
local current_seed = ""

local function seedToNumber(seed_str)
    local hash = 5381
    for i = 1, #seed_str do
        hash = ((hash * 33) + seed_str:byte(i)) % 2147483647
    end
    if hash == 0 then hash = 1 end
    return hash
end

function RNG.setSeed(seed_str)
    current_seed = seed_str
    local numeric = seedToNumber(seed_str)
    generator:setSeed(numeric)
end

function RNG.getSeed()
    return current_seed
end

function RNG.generateSeed()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local temp = love.math.newRandomGenerator(os.time() + love.timer.getTime() * 1000000)
    local parts = {}
    for i = 1, 8 do
        local idx = temp:random(1, #chars)
        table.insert(parts, chars:sub(idx, idx))
    end
    return table.concat(parts)
end

function RNG.random(a, b)
    if a and b then
        return generator:random(a, b)
    elseif a then
        return generator:random(a)
    else
        return generator:random()
    end
end

function RNG.getState()
    return generator:getState()
end

function RNG.setState(state_str)
    generator:setState(state_str)
end

return RNG
