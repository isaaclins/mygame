local RNG = require("functions/rng")
local Settings = require("functions/settings")
local Verbose = require("functions/verbose")

local StickerEffects = {}

local sticker_defs = nil
local sticker_by_id = nil

local guard = {
	event_depth = 0,
	trigger_count = 0,
	max_depth = 24,
	max_triggers = 480,
	aborted = false,
	chaos_score = 0,
}

local function loadStickerDefs()
	if sticker_defs then
		return
	end
	local createStickers = require("content/stickers")
	sticker_defs = createStickers()
	sticker_by_id = {}
	for _, st in ipairs(sticker_defs) do
		sticker_by_id[st.id] = st
	end
end

function StickerEffects.getStickerCatalog()
	loadStickerDefs()
	return sticker_defs
end

function StickerEffects.getStickerById(id)
	loadStickerDefs()
	return sticker_by_id[id]
end

local function listStickerIds(die)
	local ids = {}
	for id, st in pairs(die.stickers or {}) do
		if (st.stacks or 0) > 0 then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	return ids
end

local function beginEvent(context)
	if guard.aborted then
		return false
	end
	guard.event_depth = guard.event_depth + 1
	if guard.event_depth > guard.max_depth then
		guard.aborted = true
		if context and context.player then
			context.player.sticker_guard_tripped = true
		end
		if Settings.get("sticker_debug_telemetry") then
			print("[stickers] Guard abort: depth limit reached")
		end
		guard.event_depth = guard.event_depth - 1
		return false
	end
	return true
end

local function endEvent()
	guard.event_depth = math.max(0, guard.event_depth - 1)
end

local function registerTrigger(context, weight)
	guard.trigger_count = guard.trigger_count + 1
	guard.chaos_score = guard.chaos_score + (weight or 1)
	if guard.trigger_count > guard.max_triggers then
		guard.aborted = true
		if context and context.player then
			context.player.sticker_guard_tripped = true
		end
		if Settings.get("sticker_debug_telemetry") then
			print("[stickers] Guard abort: trigger budget exceeded")
		end
		return false
	end
	return true
end

local function applyStickerHook(event_name, id, stacks, die, context)
	local state = die._sticker_state or {}
	die._sticker_state = state
	local player = context and context.player or nil
	local rolled_this_event = not die.locked
	local before_value = die.value
	local before_rerolls = player and player.rerolls_remaining or nil
	local before_bonus = context and context.bonus or nil
	local before_mult_bonus = context and context.mult_bonus or nil
	local before_score_mult = context and context.score_mult or nil

	if id == "bad_luck" then
		if event_name == "onRoundStart" and player and player.round >= 44 then
			local deathChancePercent = math.max(0.1, 50 - (1.111 * stacks))
			if RNG.random() <= (deathChancePercent / 100) then
				player.sticker_instant_death = true
				player.sticker_death_reason = "Bad Luck?"
			end
		elseif event_name == "onPreScore" and context then
			context.score_mult = (context.score_mult or 1) * (1.5 ^ stacks)
		end
	elseif id == "lucky_streak" then
		if event_name == "onRoundStart" then
			state.last_roll_value = nil
			state.strike_mult = 1
		elseif event_name == "onPostRoll" and player and rolled_this_event then
			if state.last_roll_value and state.last_roll_value == die.value then
				player.rerolls_remaining = player.rerolls_remaining + (2 * stacks)
				state.strike_mult = (state.strike_mult or 1) * (1.33 ^ stacks)
			end
			state.last_roll_value = die.value
		end
	elseif id == "momentum" then
		if event_name == "onRoundStart" then
			state.ones_rolled = 0
		elseif event_name == "onPostRoll" and rolled_this_event then
			if die.value == 1 then
				state.ones_rolled = (state.ones_rolled or 0) + 1
			end
		elseif event_name == "onPreScore" and context then
			local ones = state.ones_rolled or 0
			if ones > 0 then
				-- True multiplicative scaling across both rolled ones and sticker stacks.
				local factor = 1.2 ^ (ones * stacks)
				context.score_mult = (context.score_mult or 1) * factor
			end
		end
	elseif id == "risk_reward" then
		if event_name == "onPostRoll" and rolled_this_event then
			if die.value <= 3 then
				die.value = math.min(6, die.value + 2)
			else
				die.value = math.max(1, die.value - 1)
			end
		end
	elseif id == "jackpot" then
		if event_name == "onRoundStart" then
			state.jackpot_bonus = 0
		elseif event_name == "onPostRoll" and rolled_this_event then
			if die.value == 6 then
				state.jackpot_bonus = (state.jackpot_bonus or 0) + stacks
			end
		elseif event_name == "onPreScore" and context and (state.jackpot_bonus or 0) > 0 then
			local strike_mult = state.strike_mult or 1
			local repeat_factor = 1 + (state.jackpot_bonus or 0)
			context.score_mult = (context.score_mult or 1) * repeat_factor * strike_mult
		end
	elseif id == "reverse" then
		if event_name == "onPostRoll" and rolled_this_event then
			die.value = 7 - die.value
		end
	elseif id == "odd_todd" then
		if event_name == "onPreScore" and context and die.value % 2 == 1 then
			context.mult_bonus = (context.mult_bonus or 0) + (0.5 * stacks)
		end
	elseif id == "even_steven" then
		if event_name == "onPreScore" and context and die.value % 2 == 0 then
			context.mult_bonus = (context.mult_bonus or 0) + (0.5 * stacks)
		end
	elseif id == "loaded_dice" then
		if event_name == "onRoundStart" then
			if die.die_type == "Normal" or die.die_type == "vanilla" then
				die.weights = { 0.8, 0.8, 1.0, 1.1, 1.2, 1.3 }
			end
		end
	elseif id == "all_in" then
		-- All In placement/infinite stacking is enforced in die:addSticker/canAddSticker.
		-- Extra rule: at round end, grow the single non-All In stackable sticker by +1.
		if event_name == "onRoundEnd" then
			local ids = {}
			for sid, st in pairs(die.stickers or {}) do
				if sid ~= "all_in" and (st.stacks or 0) > 0 and st.stackable == true then
					table.insert(ids, sid)
				end
			end
			table.sort(ids)
			local target_id = ids[1]
			if target_id then
				local target = die.stickers[target_id]
				if target then
					target.stacks = (target.stacks or 0) + 1
				end
			end
		end
	end

	local after_rerolls = player and player.rerolls_remaining or nil
	local after_bonus = context and context.bonus or nil
	local after_mult_bonus = context and context.mult_bonus or nil
	local after_score_mult = context and context.score_mult or nil
	Verbose.logf(
		"sticker",
		"%s die=%s sticker=%s x%d val:%s->%s rerolls:%s->%s bonus:%s->%s mult_bonus:%s->%s score_mult:%s->%s",
		event_name,
		tostring(die.name),
		id,
		stacks,
		tostring(before_value),
		tostring(die.value),
		tostring(before_rerolls),
		tostring(after_rerolls),
		tostring(before_bonus),
		tostring(after_bonus),
		tostring(before_mult_bonus),
		tostring(after_mult_bonus),
		tostring(before_score_mult),
		tostring(after_score_mult)
	)
end

function StickerEffects.dispatchForDie(event_name, die, context)
	if not die or not die.stickers then
		return
	end
	if not beginEvent(context) then
		return
	end

	local ids = listStickerIds(die)
	Verbose.logf("sticker", "dispatch %s for %s stickers=%d", event_name, tostring(die.name), #ids)
	for _, id in ipairs(ids) do
		local sticker = die.stickers[id]
		local stacks = sticker and sticker.stacks or 0
		if stacks > 0 then
			if not registerTrigger(context, 1 + stacks * 0.1) then
				break
			end
			applyStickerHook(event_name, id, stacks, die, context)
		end
	end

	endEvent()
end

function StickerEffects.dispatchForPlayer(event_name, player, context)
	if not player then
		return
	end
	context = context or {}
	context.player = context.player or player
	for _, die in ipairs(player.dice_pool or {}) do
		context.die = die
		StickerEffects.dispatchForDie(event_name, die, context)
		if guard.aborted then
			break
		end
	end
	context.die = nil
end

function StickerEffects.beginRound(player)
	guard.event_depth = 0
	guard.trigger_count = 0
	guard.aborted = false
	guard.chaos_score = 0

	for _, die in ipairs(player.dice_pool or {}) do
		die._sticker_state = die._sticker_state or {}
		die._sticker_state.last_roll_value = nil
		die._sticker_state.ones_rolled = 0
		die._sticker_state.strike_mult = 1
		die._sticker_state.jackpot_bonus = 0
	end

	StickerEffects.dispatchForPlayer("onRoundStart", player, { player = player, phase = "round_start" })
end

function StickerEffects.resetOnInput(player)
	guard.event_depth = 0
	guard.trigger_count = 0
	guard.aborted = false
	guard.chaos_score = 0
	if player then
		player.sticker_guard_tripped = false
		player.chaos_pressure = 0
	end
end

function StickerEffects.getGuardStatus()
	return {
		aborted = guard.aborted,
		trigger_count = guard.trigger_count,
		chaos_score = guard.chaos_score,
	}
end

return StickerEffects
