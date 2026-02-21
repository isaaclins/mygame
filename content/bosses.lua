local Boss = require("objects/boss")
local RNG = require("functions/rng")

local function createBosses()
    return {
        Boss:new({
            name = "The Lockdown",
            description = "Locks a random die for the entire round",
            icon = "X",
            modifier = function(self, context)
                if context and context.player and #context.player.dice_pool > 0 then
                    local idx = RNG.random(1, #context.player.dice_pool)
                    context.player.dice_pool[idx].locked = true
                    context.player.dice_pool[idx].value = RNG.random(1, 6)
                    context.locked_by_boss = idx
                end
            end,
            revert = function(self, context)
                if context and context.locked_by_boss and context.player then
                    local die = context.player.dice_pool[context.locked_by_boss]
                    if die then die.locked = false end
                end
            end,
        }),
        Boss:new({
            name = "The Inverter",
            description = "All dice values are inverted (1/6, 2/5, 3/4)",
            icon = "~",
            modifier = function(self, context)
                if context and context.player then
                    context.invert_dice = true
                end
            end,
            revert = function(self, context)
                if context then
                    context.invert_dice = false
                end
            end,
        }),
        Boss:new({
            name = "The Collector",
            description = "Lose one random die after this round (replaced with Vanilla)",
            icon = "?",
            modifier = function(self, context)
                if context and context.player then
                    context.collector_active = true
                end
            end,
            revert = function(self, context)
                if context and context.collector_active and context.player then
                    local Die = require("objects/die")
                    local idx = RNG.random(1, #context.player.dice_pool)
                    context.player.dice_pool[idx] = Die:new({
                        name = "Vanilla Die",
                        color = "black",
                        die_type = "vanilla",
                        ability_name = "None",
                    })
                    context.collector_active = false
                end
            end,
        }),
        Boss:new({
            name = "The Miser",
            description = "Rerolls reduced by 2 this round",
            icon = "-",
            modifier = function(self, context)
                if context and context.player then
                    context.player.rerolls_remaining = math.max(0, context.player.rerolls_remaining - 2)
                    context.miser_active = true
                end
            end,
            revert = function(self, context)
                if context then context.miser_active = false end
            end,
        }),
        Boss:new({
            name = "The Silencer",
            description = "All dice abilities are suppressed this round",
            icon = "!",
            modifier = function(self, context)
                if context then
                    context.suppress_abilities = true
                end
            end,
            revert = function(self, context)
                if context then context.suppress_abilities = false end
            end,
        }),
    }
end

return createBosses
