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
    self.detect = opts.detect or function() return false, {} end
    self.description = opts.description or ""
end

function Hand:calculateScore(dice_values, matched_dice)
    local sum = 0
    for _, v in ipairs(matched_dice or dice_values) do
        sum = sum + v
    end
    local score = (self.base_score + sum) * self.multiplier
    return math.floor(score)
end

function Hand:upgrade()
    if self.upgrade_level >= self.max_upgrade then return false end
    self.upgrade_level = self.upgrade_level + 1
    self.base_score = self.base_score + math.floor(self.base_score * 0.3)
    self.multiplier = self.multiplier + 0.5
    return true
end

function Hand:getUpgradeCost()
    return 5 + self.upgrade_level * self.upgrade_level * 5
end

function Hand:getDisplayScore()
    return self.base_score .. " × " .. string.format("%.1f", self.multiplier)
end

return Hand
