local Die = require("objects/die")
local RNG = require("functions/rng")

local function createDiceTypes()
    return {
        Die:new({
            name = "Normal Die",
            color = "black",
            die_type = "Normal",
            ability_name = "None",
            ability_desc = "A standard die with no special abilities.",
        }),
        Die:new({
            name = "Light Die",
            color = "blue",
            die_type = "light",
            ability_name = "Featherweight",
            ability_desc = "Only rolls 1, 2, or 3.",
            weights = { 1, 1, 1, 0, 0, 0 },
            glow_color = { 0.6, 0.85, 1.0, 0.6 },
        }),
        Die:new({
            name = "Heavy Die",
            color = "blue",
            die_type = "heavy",
            ability_name = "Heavyweight",
            ability_desc = "Only rolls  4, 5, or 6.",
            weights = { 0, 0, 0, 1, 1, 1 },
            glow_color = { 0.2, 0.25, 0.7, 0.6 },
        }),
        Die:new({
            name = "Glass Die",
            color = "red",
            die_type = "glass",
            ability_name = "Glass Cannon",
            ability_desc = "x1.5 score mult when scored with. 10% to shatter on reroll.",
            glow_color = { 1.0, 0.3, 0.3, 0.6 },
        }),
        Die:new({
            name = "Odd Die",
            color = "green",
            die_type = "odd",
            ability_name = "Odd Synergy",
            ability_desc = "If value is odd, adds +5 to score.",
            glow_color = { 0.2, 0.8, 0.3, 0.6 },
            ability = function(self, context)
                if context and context.scoring and self.value % 2 == 1 then
                    context.bonus = (context.bonus or 0) + 5 + self.upgrade_level * 3
                    return "odd_bonus"
                end
            end,
        }),
        Die:new({
            name = "Even Die",
            color = "green",
            die_type = "even",
            ability_name = "Even Synergy",
            ability_desc = "If value is even, adds +5 to score.",
            glow_color = { 0.2, 0.8, 0.3, 0.6 },
            ability = function(self, context)
                if context and context.scoring and self.value % 2 == 0 then
                    context.bonus = (context.bonus or 0) + 5 + self.upgrade_level * 3
                    return "even_bonus"
                end
            end,
        }),
        Die:new({
            name = "Wild Die",
            color = "red",
            die_type = "wild",
            ability_name = "Wild Card",
            ability_desc = "Choose its value once per round (click to set).",
            glow_color = { 1.0, 0.84, 0.0, 0.6 },
        }),
        Die:new({
            name = "Mirror Die",
            color = "blue",
            die_type = "mirror",
            ability_name = "Reflection",
            ability_desc = "Flips value after rolling (1/6, 2/5, 3/4).",
            glow_color = { 0.5, 0.3, 0.9, 0.6 },
        }),
        Die:new({
            name = "Echo Die",
            color = "blue",
            die_type = "echo",
            ability_name = "Echo",
            ability_desc = "Copies another die's value after rolling.",
            glow_color = { 0.3, 0.7, 0.9, 0.6 },
            ability = function(self, context)
                if context and context.dice_pool and #context.dice_pool > 1 then
                    local others = {}
                    for _, d in ipairs(context.dice_pool) do
                        if d ~= self and d.die_type ~= "echo" then
                            table.insert(others, d)
                        end
                    end
                    if #others > 0 then
                        local target = others[RNG.random(1, #others)]
                        self.value = target.value
                        return "echo"
                    end
                end
            end,
        }),
    }
end

return createDiceTypes
