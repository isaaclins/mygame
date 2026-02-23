local Class = require("objects/class")
local Hand = Class:extend()

function Hand:init(opts)
    opts = opts or {}
    self.name = opts.name or "High Roll"
    self.base_score = opts.base_score or 5
    self.multiplier = opts.multiplier or 1
    self.upgrade_level = opts.upgrade_level or 0
    self.max_upgrade = opts.max_upgrade or 5
    self.priority = opts.priority or 0
    self.min_dice = opts.min_dice or 1
    self.detect = opts.detect or function() return false, {} end
    self.description = opts.description or ""
    self.is_x_of_a_kind = opts.is_x_of_a_kind or false
    self._original_base = self.base_score
    self._original_mult = self.multiplier
    self._upgrade_base_bonus = 0
    self._upgrade_mult_bonus = 0
end

function Hand:calculateScore(dice_values, matched_dice)
    local sum = 0
    for _, v in ipairs(matched_dice or dice_values) do
        sum = sum + v
    end
    local score = (self.base_score + sum) * self.multiplier
    return math.floor(score)
end

function Hand:calculateXOfAKindScore(x, matched_dice)
    local base = math.floor(5 * x * (x - 1)) + self._upgrade_base_bonus
    local mult = (x - 1) + self._upgrade_mult_bonus
    local sum = 0
    for _, v in ipairs(matched_dice) do sum = sum + v end
    return math.floor((base + sum) * mult), base, mult
end

function Hand:upgrade()
    if self.upgrade_level >= self.max_upgrade then return false end
    self.upgrade_level = self.upgrade_level + 1
    if self.is_x_of_a_kind then
        local current_base = self._original_base + self._upgrade_base_bonus
        local increment = math.floor(current_base * 0.3)
        self._upgrade_base_bonus = self._upgrade_base_bonus + increment
        self._upgrade_mult_bonus = self._upgrade_mult_bonus + 0.5
        self.base_score = self._original_base + self._upgrade_base_bonus
        self.multiplier = self._original_mult + self._upgrade_mult_bonus
    else
        self.base_score = self.base_score + math.floor(self.base_score * 0.3)
        self.multiplier = self.multiplier + 0.5
    end
    return true
end

function Hand:getUpgradeCost()
    local level = self.upgrade_level
    if level >= 5 then
        return 5 + level * level * 8
    end
    return 5 + level * level * 5
end

function Hand:getDisplayScore()
    local UI = require("functions/ui")
    if self.is_x_of_a_kind then
        local base3 = math.floor(5 * 3 * 2) + self._upgrade_base_bonus
        local mult3 = 2 + self._upgrade_mult_bonus
        local mult_str = mult3 >= 1e3 and UI.abbreviate(mult3) or string.format("%.1f", mult3)
        return UI.abbreviate(base3) .. " x " .. mult_str .. "+"
    end
    local mult_str = self.multiplier >= 1e3 and UI.abbreviate(self.multiplier) or string.format("%.1f", self.multiplier)
    return UI.abbreviate(self.base_score) .. " x " .. mult_str
end

function Hand:setUpgradeLevel(level)
    self.base_score = self._original_base
    self.multiplier = self._original_mult
    self.upgrade_level = 0
    self._upgrade_base_bonus = 0
    self._upgrade_mult_bonus = 0
    for _ = 1, level do self:upgrade() end
end

return Hand
