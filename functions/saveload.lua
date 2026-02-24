local SaveLoad = {}

local SAVE_FILE = "savedata.lua"

local function serialize(val, indent)
	indent = indent or 0
	local pad = string.rep("  ", indent)
	local t = type(val)

	if t == "number" then
		return tostring(val)
	elseif t == "string" then
		return string.format("%q", val)
	elseif t == "boolean" then
		return tostring(val)
	elseif t == "nil" then
		return "nil"
	elseif t == "table" then
		local parts = {}
		local pad2 = string.rep("  ", indent + 1)

		local is_array = true
		local max_i = 0
		for k, _ in pairs(val) do
			if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
				is_array = false
				break
			end
			if k > max_i then
				max_i = k
			end
		end
		if is_array and max_i == #val then
			for i, v in ipairs(val) do
				table.insert(parts, pad2 .. serialize(v, indent + 1))
			end
		else
			is_array = false
			for k, v in pairs(val) do
				if type(k) == "string" then
					table.insert(parts, pad2 .. "[" .. string.format("%q", k) .. "] = " .. serialize(v, indent + 1))
				elseif type(k) == "number" then
					table.insert(parts, pad2 .. "[" .. k .. "] = " .. serialize(v, indent + 1))
				end
			end
		end
		return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
	end
	return "nil"
end

function SaveLoad.serializeDie(die)
	local data = {
		name = die.name,
		color = die.color,
		die_type = die.die_type,
		value = die.value,
		locked = die.locked or false,
		wild_choice = die.wild_choice,
		ability_name = die.ability_name,
		ability_desc = die.ability_desc,
		upgrade_level = die.upgrade_level,
		max_upgrade = die.max_upgrade,
		weights = {},
		items = {},
		stickers = die.getSerializedStickers and die:getSerializedStickers() or {},
	}
	for i, w in ipairs(die.weights) do
		data.weights[i] = w
	end
	if die.glow_color then
		data.glow_color = { die.glow_color[1], die.glow_color[2], die.glow_color[3], die.glow_color[4] }
	end
	if die._sort_order then
		data._sort_order = die._sort_order
	end
	for _, item in ipairs(die.items or {}) do
		table.insert(data.items, {
			name = item.name,
			triggered_this_round = item.triggered_this_round or false,
		})
	end
	return data
end

function SaveLoad.serializeHand(hand)
	return {
		name = hand.name,
		base_score = hand.base_score,
		multiplier = hand.multiplier,
		upgrade_level = hand.upgrade_level,
		max_upgrade = hand.max_upgrade,
	}
end

function SaveLoad.buildSaveData(game_state, player, rng_state, current_boss_name)
	if not player then
		return nil
	end
	local data = {
		version = 3,
		state = game_state,
		seed = player.seed or "",
		rng_state = rng_state or "",
		round = player.round,
		currency = player.currency,
		score = player.score,
		base_rerolls = player.base_rerolls,
		max_rerolls = player.max_rerolls,
		rerolls_remaining = player.rerolls_remaining,
		max_dice = player.max_dice,
		free_choice_used = player.free_choice_used,
		limit_break_count = player.limit_break_count,
		interest_cap = player.interest_cap,
		current_boss_name = current_boss_name,
		dice_pool = {},
		hands = {},
		item_names = {},
		item_states = {},
	}

	for _, die in ipairs(player.dice_pool) do
		table.insert(data.dice_pool, SaveLoad.serializeDie(die))
	end

	for _, hand in ipairs(player.hands) do
		table.insert(data.hands, SaveLoad.serializeHand(hand))
	end

	for _, item in ipairs(player.items) do
		table.insert(data.item_names, item.name)
		table.insert(data.item_states, {
			name = item.name,
			triggered_this_round = item.triggered_this_round or false,
		})
	end

	return data
end

function SaveLoad.save(game_state, player, rng_state, current_boss_name)
	local data = SaveLoad.buildSaveData(game_state, player, rng_state, current_boss_name)
	if not data then
		return false
	end

	local content = "return " .. serialize(data, 0) .. "\n"
	local ok, err = love.filesystem.write(SAVE_FILE, content)
	if ok then
		print("[save] Game saved successfully")
	else
		print("[save] Failed to save: " .. tostring(err))
	end
	return ok
end

function SaveLoad.hasSave()
	return love.filesystem.getInfo(SAVE_FILE) ~= nil
end

function SaveLoad.load()
	if not SaveLoad.hasSave() then
		return nil
	end

	local chunk, err = love.filesystem.load(SAVE_FILE)
	if not chunk then
		print("[load] Failed to load save: " .. tostring(err))
		return nil
	end

	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" then
		print("[load] Corrupt save data")
		return nil
	end

	if data.version ~= 1 and data.version ~= 2 and data.version ~= 3 then
		print("[load] Incompatible save version")
		return nil
	end

	return data
end

function SaveLoad.deleteSave()
	if SaveLoad.hasSave() then
		love.filesystem.remove(SAVE_FILE)
		print("[save] Save deleted")
	end
end

function SaveLoad.restorePlayer(data, Player, Die, createDiceTypes, createItems, createHands)
	local player = Player:new()
	player.round = data.round or 1
	player.currency = data.currency or 0
	player.score = data.score or 0
	player.base_rerolls = data.base_rerolls or 3
	player.max_rerolls = data.max_rerolls or player.base_rerolls
	player.rerolls_remaining = data.rerolls_remaining or player.max_rerolls
	player.max_dice = data.max_dice or 5
	player.free_choice_used = data.free_choice_used or false
	player.limit_break_count = data.limit_break_count or 0
	player.interest_cap = data.interest_cap or 5

	local templates = {}
	for _, dt in ipairs(createDiceTypes()) do
		templates[dt.die_type] = dt
	end

	player.dice_pool = {}
	for i, dd in ipairs(data.dice_pool or {}) do
		local template = templates[dd.die_type]
		local die = Die:new({
			name = dd.name,
			color = dd.color,
			die_type = dd.die_type,
			value = dd.value,
			ability_name = dd.ability_name,
			ability_desc = dd.ability_desc,
			upgrade_level = dd.upgrade_level or 0,
			max_upgrade = dd.max_upgrade or 3,
			weights = dd.weights,
			glow_color = dd.glow_color,
			stickers = dd.stickers or {},
		})
		die.locked = dd.locked or false
		die.wild_choice = dd.wild_choice
		if template and template.ability then
			die.ability = template.ability
		end
		die._sort_order = dd._sort_order or i
		table.insert(player.dice_pool, die)
	end

	local base_hands = createHands()
	player.hands = {}
	local saved_hands = data.hands or {}

	local saved_by_name = {}
	for _, hd in ipairs(saved_hands) do
		if hd.name then
			saved_by_name[hd.name] = hd
		end
	end

	local old_xoak_names = {
		"Three of a Kind",
		"Four of a Kind",
		"Five of a Kind",
		"Six of a Kind",
		"Seven of a Kind",
	}
	local merged_xoak_level = 0
	for _, old_name in ipairs(old_xoak_names) do
		local hd = saved_by_name[old_name]
		if hd and (hd.upgrade_level or 0) > merged_xoak_level then
			merged_xoak_level = hd.upgrade_level
		end
	end

	for _, hand in ipairs(base_hands) do
		local hd = saved_by_name[hand.name]
		if hd then
			hand.max_upgrade = math.max(hand.max_upgrade, hd.max_upgrade or hand.max_upgrade)
			local lvl = hd.upgrade_level or 0
			if lvl > 0 then
				hand:setUpgradeLevel(lvl)
			end
		elseif hand.is_x_of_a_kind and merged_xoak_level > 0 then
			hand:setUpgradeLevel(merged_xoak_level)
		end
		table.insert(player.hands, hand)
	end

	local all_items = createItems()
	local item_lookup = {}
	for _, item in ipairs(all_items) do
		item_lookup[item.name] = item
	end
	player.items = {}
	for idx, name in ipairs(data.item_names or {}) do
		local item = item_lookup[name]
		if item then
			local restored = item:clone()
			local st = (data.item_states or {})[idx]
			if st then
				restored.triggered_this_round = st.triggered_this_round or false
			end
			table.insert(player.items, restored)
		end
	end

	for di, dd in ipairs(data.dice_pool or {}) do
		local die = player.dice_pool[di]
		if die and dd.items then
			die.items = {}
			for _, saved in ipairs(dd.items) do
				local template = item_lookup[saved.name]
				if template then
					local restored = template:clone()
					restored.triggered_this_round = saved.triggered_this_round or false
					table.insert(die.items, restored)
				end
			end
		end
	end

	return player
end

return SaveLoad
