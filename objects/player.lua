local Class = require("objects/class")
local RNG = require("functions/rng")
local Player = Class:extend()

function Player:init()
    self.dice_pool = {}
    self.hands = {}
    self.items = {}
    self.base_rerolls = 3
    self.max_rerolls = self.base_rerolls
    self.rerolls_remaining = self.max_rerolls
    self.currency = 0
    self.round = 1
    self.score = 0
    self.max_dice = 5
    self.free_choice_used = false
end

function Player:rollAllDice()
    for _, die in ipairs(self.dice_pool) do
        if not die.locked then
            die:startRoll(0.4 + RNG.random() * 0.3)
        end
    end
end

function Player:rerollUnlocked()
    if self.rerolls_remaining <= 0 then return false end
    local any_unlocked = false
    for _, die in ipairs(self.dice_pool) do
        if not die.locked then
            die:startRoll(0.3 + RNG.random() * 0.2)
            any_unlocked = true
        end
    end
    if any_unlocked then
        self.rerolls_remaining = self.rerolls_remaining - 1
    end
    return any_unlocked
end

function Player:updateDiceRolls(dt)
    local all_done = true
    for _, die in ipairs(self.dice_pool) do
        if die.rolling then
            local finished = die:updateRoll(dt)
            if not finished then
                all_done = false
            end
        end
    end
    return all_done
end

function Player:anyDiceRolling()
    for _, die in ipairs(self.dice_pool) do
        if die.rolling then return true end
    end
    return false
end

function Player:lockDie(index)
    if self.dice_pool[index] then
        self.dice_pool[index]:toggleLock()
    end
end

function Player:unlockAllDice()
    for _, die in ipairs(self.dice_pool) do
        die.locked = false
    end
end

function Player:getDiceValues()
    local values = {}
    for _, die in ipairs(self.dice_pool) do
        table.insert(values, die.value)
    end
    return values
end

function Player:replaceDie(index, new_die)
    if index >= 1 and index <= #self.dice_pool then
        self.dice_pool[index] = new_die
    end
end

function Player:addItem(item)
    table.insert(self.items, item)
end

function Player:applyItems(context)
    for _, item in ipairs(self.items) do
        item:apply(context)
    end
end

function Player:resetItemTriggers()
    for _, item in ipairs(self.items) do
        item:resetRound()
    end
end

function Player:startNewRound()
    self.max_rerolls = self.base_rerolls
    self.rerolls_remaining = self.max_rerolls
    self.free_choice_used = false
    self:unlockAllDice()
    self:resetItemTriggers()

    for _, die in ipairs(self.dice_pool) do
        die.wild_choice = nil
    end

    for _, item in ipairs(self.items) do
        if item.trigger_type == "passive" then
            item:apply({ player = self, phase = "round_start" })
        end
    end
end

function Player:getTargetScore()
    local base = 40
    local scaling = 1.35
    return math.floor(base * (scaling ^ (self.round - 1)))
end

function Player:earnCurrency(score)
    local earned = math.max(5, math.floor(score / 8))
    self.currency = self.currency + earned
    return earned
end

function Player:isBossRound()
    return self.round % 4 == 0
end

return Player
