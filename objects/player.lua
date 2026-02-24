local Class = require("objects/class")
local StickerEffects = require("functions/sticker_effects")
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
	self.limit_break_count = 0
	self.interest_cap = 5
	self.sticker_instant_death = false
	self.sticker_death_reason = nil
	self.sticker_guard_tripped = false
	self.chaos_pressure = 0
end

function Player:rollAllDice()
	for _, die in ipairs(self.dice_pool) do
		if not die.locked then
			die:startRoll(0.4 + math.random() * 0.3)
		end
	end
end

function Player:rerollUnlocked()
	if self.rerolls_remaining <= 0 then
		return false
	end
	local any_unlocked = false
	for _, die in ipairs(self.dice_pool) do
		if not die.locked then
			die:startRoll(0.3 + math.random() * 0.2)
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
		if die.rolling then
			return true
		end
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
		StickerEffects.dispatchForDie("onBeforeDieReplace", self.dice_pool[index], { player = self, replacement = new_die })
		new_die._sort_order = self.dice_pool[index]._sort_order
		self.dice_pool[index] = new_die
	end
end

function Player:sortDice(mode)
	for i, die in ipairs(self.dice_pool) do
		if not die._sort_order then
			die._sort_order = i
		end
	end

	if mode == "default" then
		table.sort(self.dice_pool, function(a, b)
			return (a._sort_order or 0) < (b._sort_order or 0)
		end)
	elseif mode == "value_asc" then
		table.sort(self.dice_pool, function(a, b)
			if a.value ~= b.value then
				return a.value < b.value
			end
			return (a._sort_order or 0) < (b._sort_order or 0)
		end)
	elseif mode == "value_desc" then
		table.sort(self.dice_pool, function(a, b)
			if a.value ~= b.value then
				return a.value > b.value
			end
			return (a._sort_order or 0) < (b._sort_order or 0)
		end)
	elseif mode == "type" then
		table.sort(self.dice_pool, function(a, b)
			if a.die_type ~= b.die_type then
				return a.die_type < b.die_type
			end
			return (a._sort_order or 0) < (b._sort_order or 0)
		end)
	elseif mode == "even_first" then
		table.sort(self.dice_pool, function(a, b)
			local a_even = a.value % 2 == 0
			local b_even = b.value % 2 == 0
			if a_even ~= b_even then
				return a_even
			end
			if a.value ~= b.value then
				return a.value < b.value
			end
			return (a._sort_order or 0) < (b._sort_order or 0)
		end)
	elseif mode == "odd_first" then
		table.sort(self.dice_pool, function(a, b)
			local a_odd = a.value % 2 == 1
			local b_odd = b.value % 2 == 1
			if a_odd ~= b_odd then
				return a_odd
			end
			if a.value ~= b.value then
				return a.value < b.value
			end
			return (a._sort_order or 0) < (b._sort_order or 0)
		end)
	elseif mode == "combo" then
		table.sort(self.dice_pool, function(a, b)
			if a.locked ~= b.locked then
				return a.locked
			end
			local ac = a._combo_index or 999
			local bc = b._combo_index or 999
			if ac ~= bc then
				return ac < bc
			end
			if a.value ~= b.value then
				return a.value > b.value
			end
			return (a._sort_order or 0) < (b._sort_order or 0)
		end)
	end
end

function Player:addItem(item)
	table.insert(self.items, item)
end

function Player:forEachItem(fn)
	for _, item in ipairs(self.items) do
		fn(item, nil)
	end
	for _, die in ipairs(self.dice_pool) do
		for _, item in ipairs(die.items or {}) do
			fn(item, die)
		end
	end
end

function Player:applyItems(context)
	context = context or { player = self, dice_pool = self.dice_pool }
	for _, item in ipairs(self.items) do
		item:apply(context)
	end
	local previous_owner = context.owner_die
	for _, die in ipairs(self.dice_pool) do
		context.owner_die = die
		for _, item in ipairs(die.items or {}) do
			item:apply(context)
		end
	end
	context.owner_die = previous_owner
end

function Player:resetItemTriggers()
	self:forEachItem(function(item)
		item:resetRound()
	end)
end

function Player:consumeItemChargeByName(name)
	for _, item in ipairs(self.items) do
		if item.name == name and not item.triggered_this_round then
			item.triggered_this_round = true
			return true
		end
	end
	for _, die in ipairs(self.dice_pool) do
		for _, item in ipairs(die.items or {}) do
			if item.name == name and not item.triggered_this_round then
				item.triggered_this_round = true
				return true
			end
		end
	end
	return false
end

function Player:getItemTriggerSnapshot()
	local snapshot = { personal = {}, dice = {} }
	for i, item in ipairs(self.items) do
		snapshot.personal[i] = item.triggered_this_round
	end
	for di, die in ipairs(self.dice_pool) do
		snapshot.dice[di] = {}
		for ii, item in ipairs(die.items or {}) do
			snapshot.dice[di][ii] = item.triggered_this_round
		end
	end
	return snapshot
end

function Player:restoreItemTriggerSnapshot(snapshot)
	if not snapshot then
		return
	end
	for i, item in ipairs(self.items) do
		local v = snapshot.personal and snapshot.personal[i]
		if v ~= nil then
			item.triggered_this_round = v
		end
	end
	for di, die in ipairs(self.dice_pool) do
		local die_snapshot = snapshot.dice and snapshot.dice[di]
		if die_snapshot then
			for ii, item in ipairs(die.items or {}) do
				local v = die_snapshot[ii]
				if v ~= nil then
					item.triggered_this_round = v
				end
			end
		end
	end
end

function Player:startNewRound()
	self.sticker_instant_death = false
	self.sticker_death_reason = nil
	self.sticker_guard_tripped = false
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
			item:apply({ player = self, dice_pool = self.dice_pool, phase = "round_start" })
		end
	end
	for _, die in ipairs(self.dice_pool) do
		for _, item in ipairs(die.items or {}) do
			if item.trigger_type == "passive" then
				item:apply({ player = self, dice_pool = self.dice_pool, owner_die = die, phase = "round_start" })
			end
		end
	end

	StickerEffects.beginRound(self)
end

function Player:getTargetScore()
	local base = 40
	local scaling = 1.35
	local target = base * (scaling ^ (self.round - 1))
	if self:isBossRound() and (self.chaos_pressure or 0) > 0 then
		local reactive = 1 + math.min(2.0, self.chaos_pressure / 120)
		target = target * reactive
	end
	return math.floor(target)
end

function Player:earnCurrency(score)
	local breakdown = {}
	local total = 0

	local target = self:getTargetScore()
	local base = math.max(5, math.floor(target / 8))
	table.insert(breakdown, { label = "Round Reward", amount = base })
	total = total + base

	if score and score >= target * 2 then
		local bonus = math.floor(score / 10)
		table.insert(breakdown, { label = "Overkill Bonus (2x+)", amount = bonus })
		total = total + bonus
	end

	if self.rerolls_remaining > 0 then
		table.insert(breakdown, {
			label = "Unused Rerolls (" .. self.rerolls_remaining .. ")",
			amount = self.rerolls_remaining,
		})
		total = total + self.rerolls_remaining
	end

	local interest = math.floor(self.currency / 5)
	if interest > 0 then
		table.insert(breakdown, { label = "Interest (1 per $5)", amount = interest })
		total = total + interest
	end

	self.currency = self.currency + total
	return total, breakdown
end

function Player:applyLimitBreak()
	self.limit_break_count = self.limit_break_count + 1
	for _, hand in ipairs(self.hands) do
		hand.max_upgrade = hand.max_upgrade + 5
	end
	for _, die in ipairs(self.dice_pool) do
		die.max_upgrade = die.max_upgrade + 2
	end
	self.max_dice = self.max_dice + 2
	self.interest_cap = self.interest_cap + 3
end

function Player:isBossRound()
	return self.round % 4 == 0
end

return Player
