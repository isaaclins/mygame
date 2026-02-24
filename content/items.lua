local Item = require("objects/item")

local function createItems()
	return {
		Item:new({
			name = "Extra Reroll",
			description = "+1 reroll per round",
			icon = "R+",
			cost = 10,
			trigger_type = "passive",
			target_scope = "personal",
			effect = function(self, context)
				if context and context.phase == "round_start" and context.player then
					context.player.max_rerolls = context.player.max_rerolls + 1
					context.player.rerolls_remaining = context.player.max_rerolls
				end
			end,
		}),
		Item:new({
			name = "Even Steven",
			description = "This die adds +0.5 mult when it rolls even",
			icon = "2x",
			cost = 15,
			trigger_type = "once",
			target_scope = "dice",
			targeting = "shop_select_die",
			effect = function(self, context)
				if context and context.scoring and context.owner_die and context.owner_die.value % 2 == 0 then
					context.mult_bonus = (context.mult_bonus or 0) + 0.5
				end
			end,
		}),
		Item:new({
			name = "Odd Todd",
			description = "This die adds +0.5 mult when it rolls odd",
			icon = "1x",
			cost = 15,
			trigger_type = "once",
			target_scope = "dice",
			targeting = "shop_select_die",
			effect = function(self, context)
				if context and context.scoring and context.owner_die and context.owner_die.value % 2 == 1 then
					context.mult_bonus = (context.mult_bonus or 0) + 0.5
				end
			end,
		}),
		Item:new({
			name = "Lucky Penny",
			description = "+3 currency after each round",
			icon = "$+",
			cost = 8,
			trigger_type = "once",
			target_scope = "personal",
			effect = function(self, context)
				if context and context.phase == "earn" and context.player then
					local bonus = 3
					context.player.currency = context.player.currency + bonus
					if context.currency_breakdown then
						table.insert(context.currency_breakdown, { label = "Lucky Penny", amount = bonus })
					end
				end
			end,
		}),
		Item:new({
			name = "Insurance",
			description = "Prevents the first Glass Die shatter per round",
			icon = "!",
			cost = 12,
			trigger_type = "passive",
			target_scope = "personal",
			effect = function(self, context) end,
		}),
		Item:new({
			name = "High Roller",
			description = "+15 base score to all hands",
			icon = "H+",
			cost = 20,
			trigger_type = "once",
			target_scope = "personal",
			effect = function(self, context)
				if context and context.scoring then
					context.bonus = (context.bonus or 0) + 15
				end
			end,
		}),
		Item:new({
			name = "Loaded Dice",
			description = "This die slightly favors high numbers",
			icon = "L",
			cost = 18,
			trigger_type = "passive",
			target_scope = "dice",
			targeting = "shop_select_die",
			effect = function(self, context)
				if context and context.phase == "round_start" and context.owner_die then
					local die = context.owner_die
					if die.die_type == "Normal" or die.die_type == "vanilla" then
						die.weights = { 0.8, 0.8, 1.0, 1.1, 1.2, 1.3 }
					end
				end
			end,
		}),
		Item:new({
			name = "Limit Breaker",
			description = "Raises all upgrade caps. Repeatable.",
			icon = ">>",
			cost = 500,
			consumable = true,
			trigger_type = "passive",
			target_scope = "personal",
			dynamic_cost = function(player)
				return 500 * math.floor(2 ^ player.limit_break_count)
			end,
			condition = function(player)
				if player.round >= 10 then
					return true
				end
				for _, hand in ipairs(player.hands) do
					if hand.upgrade_level >= hand.max_upgrade then
						return true
					end
				end
				return false
			end,
			effect = function(self, context)
				if context and context.player then
					context.player:applyLimitBreak()
				end
			end,
		}),
	}
end

return createItems
