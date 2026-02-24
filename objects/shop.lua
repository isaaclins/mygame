local Class = require("objects/class")
local RNG = require("functions/rng")
local Shop = Class:extend()

function Shop:init()
	self.hand_upgrades = {}
	self.dice_inventory = {}
	self.items_inventory = {}
	self.stickers_inventory = {}
	self.free_choice_used = false
	self.selected_section = 1
	self._dice_templates = {}
end

local function buildDieEntry(template)
	return {
		die = template:clone(),
		cost = 8 + template.upgrade_level * 4,
	}
end

local function isOwnedPersonalItem(player, item_name)
	for _, pi in ipairs(player.items) do
		if pi.name == item_name then
			return true
		end
	end
	return false
end

function Shop:appendRandomDieOffer()
	if not self._dice_templates or #self._dice_templates == 0 then
		return
	end

	-- Prefer a die type not currently offered; fallback to any template.
	local in_shop = {}
	for _, entry in ipairs(self.dice_inventory) do
		in_shop[entry.die.die_type] = true
	end

	local candidates = {}
	for _, dt in ipairs(self._dice_templates) do
		if not in_shop[dt.die_type] then
			table.insert(candidates, dt)
		end
	end
	if #candidates == 0 then
		candidates = self._dice_templates
	end

	local idx = RNG.random(1, #candidates)
	table.insert(self.dice_inventory, buildDieEntry(candidates[idx]))
end

function Shop:ensureDiceOffers(target_count)
	target_count = math.max(0, math.floor(target_count or 0))
	while #self.dice_inventory < target_count do
		self:appendRandomDieOffer()
		-- Safety: if templates are unavailable, appendRandomDieOffer won't add anything.
		if not self._dice_templates or #self._dice_templates == 0 then
			break
		end
	end
end

function Shop:generate(player, all_dice_types, all_items, all_stickers)
	self.free_choice_used = player.free_choice_used
	self._dice_templates = {}
	for _, dt in ipairs(all_dice_types) do
		table.insert(self._dice_templates, dt)
	end

	local all_upgradeable = {}
	local max_dice = player.max_dice or #player.dice_pool
	for i, hand in ipairs(player.hands) do
		if hand.upgrade_level < hand.max_upgrade and (hand.min_dice or 1) <= max_dice then
			table.insert(all_upgradeable, {
				hand_index = i,
				hand = hand,
				cost = hand:getUpgradeCost(),
			})
		end
	end
	self.hand_upgrades = {}
	for i = 1, math.min(5, #all_upgradeable) do
		local idx = RNG.random(1, #all_upgradeable)
		table.insert(self.hand_upgrades, all_upgradeable[idx])
		table.remove(all_upgradeable, idx)
	end

	self.dice_inventory = {}
	local available = {}
	for _, dt in ipairs(self._dice_templates) do
		table.insert(available, dt)
	end
	for i = 1, math.min(3, #available) do
		local idx = RNG.random(1, #available)
		table.insert(self.dice_inventory, buildDieEntry(available[idx]))
		table.remove(available, idx)
	end

	self.items_inventory = {}
	local avail_items = {}
	for _, item in ipairs(all_items) do
		if item.condition and not item.condition(player) then
			goto continue_item
		end
		-- Die-scoped mods are replaced by stickers and should not appear as relic offers.
		if item.target_scope == "dice" then
			goto continue_item
		end
		local is_repeatable = item.consumable
		local owned = isOwnedPersonalItem(player, item.name)
		if is_repeatable or not owned then
			if item.dynamic_cost then
				item.cost = item.dynamic_cost(player)
			end
			table.insert(avail_items, item)
		end
		::continue_item::
	end
	for i = 1, math.min(3, #avail_items) do
		local idx = RNG.random(1, #avail_items)
		local item = avail_items[idx]
		table.insert(self.items_inventory, {
			kind = "item",
			data = item,
			name = item.name,
			description = item.description,
			icon = item.icon,
			cost = item.cost,
			rarity = "relic",
		})
		table.remove(avail_items, idx)
	end

	self.stickers_inventory = {}
	local avail_stickers = {}
	for _, st in ipairs(all_stickers or {}) do
		table.insert(avail_stickers, st:clone())
	end
	for i = 1, math.min(3, #avail_stickers) do
		local idx = RNG.random(1, #avail_stickers)
		local sticker = avail_stickers[idx]
		local rarity_cost = {
			common = 8,
			uncommon = 12,
			rare = 16,
			epic = 22,
			legendary = 30,
			curse = 14,
		}
		local cost = rarity_cost[sticker.rarity] or 12
		table.insert(self.items_inventory, {
			kind = "sticker",
			data = sticker,
			name = sticker.name,
			description = sticker.description,
			icon = "ST",
			cost = cost,
			rarity = sticker.rarity,
			stack_label = sticker:getStackLabel(),
		})
		table.remove(avail_stickers, idx)
	end
end

function Shop:getBulkUpgradeCost(hand, count)
	local total = 0
	local level = hand.upgrade_level
	local max_lvl = hand.max_upgrade
	local actual = 0
	for _ = 1, count do
		if level >= max_lvl then
			break
		end
		local cost
		if level >= 5 then
			cost = 5 + level * level * 8
		else
			cost = 5 + level * level * 5
		end
		total = total + cost
		level = level + 1
		actual = actual + 1
	end
	return total, actual
end

function Shop:getBulkMaxCount(hand, budget)
	local level = hand.upgrade_level
	local max_lvl = hand.max_upgrade
	local total = 0
	local count = 0
	while level < max_lvl do
		local cost
		if level >= 5 then
			cost = 5 + level * level * 8
		else
			cost = 5 + level * level * 5
		end
		if total + cost > budget then
			break
		end
		total = total + cost
		level = level + 1
		count = count + 1
	end
	return count, total
end

function Shop:buyHandUpgrade(player, upgrade_index, bulk_count)
	local upgrade = self.hand_upgrades[upgrade_index]
	if not upgrade then
		return false, "Invalid upgrade"
	end

	if upgrade.hand.upgrade_level >= upgrade.hand.max_upgrade then
		return false, "Already maxed!"
	end

	if not self.free_choice_used then
		self.free_choice_used = true
		player.free_choice_used = true
		upgrade.hand:upgrade()
		upgrade.cost = upgrade.hand:getUpgradeCost()
		return true, "Free upgrade applied!"
	end

	local count = bulk_count or 1
	if count == 0 then
		count = 1
	end

	local total_cost, actual
	if count == -1 then
		actual, total_cost = self:getBulkMaxCount(upgrade.hand, player.currency)
	else
		total_cost, actual = self:getBulkUpgradeCost(upgrade.hand, count)
	end

	if actual == 0 then
		return false, "Already maxed!"
	end

	if player.currency < total_cost then
		return false, "Not enough currency"
	end

	player.currency = player.currency - total_cost
	for _ = 1, actual do
		upgrade.hand:upgrade()
	end
	upgrade.cost = upgrade.hand:getUpgradeCost()
	return true, "+" .. actual .. " levels!"
end

function Shop:buyDie(player, shop_die_index, player_die_index)
	local shop_entry = self.dice_inventory[shop_die_index]
	if not shop_entry then
		return false, "Invalid die"
	end

	if not self.free_choice_used then
		self.free_choice_used = true
		player.free_choice_used = true
		player:replaceDie(player_die_index, shop_entry.die)
		table.remove(self.dice_inventory, shop_die_index)
		self:appendRandomDieOffer()
		return true, "Free replacement!"
	end

	if player.currency < shop_entry.cost then
		return false, "Not enough currency"
	end

	player.currency = player.currency - shop_entry.cost
	player:replaceDie(player_die_index, shop_entry.die)
	table.remove(self.dice_inventory, shop_die_index)
	self:appendRandomDieOffer()
	return true, "Die replaced!"
end

function Shop:buyItem(player, item_index, target_die_index)
	local entry = self.items_inventory[item_index]
	if not entry then
		return false, "Invalid item"
	end
	if entry.kind == "sticker" then
		return false, "Select a die to apply this sticker"
	end
	local item = entry.data

	if player.currency < entry.cost then
		return false, "Not enough currency"
	end

	if item.consumable then
		local result = item.effect(item, { player = player })
		if result == false then
			return false, "Cannot use!"
		end
		player.currency = player.currency - entry.cost
		if item.dynamic_cost then
			local next_cost = item.dynamic_cost(player)
			item.cost = next_cost
			entry.cost = next_cost
		else
			table.remove(self.items_inventory, item_index)
		end
		return true, item.name .. " activated!"
	end

	if item.target_scope == "dice" then
		local target_die = player.dice_pool[target_die_index or 0]
		if not target_die then
			return false, "Pick a target die"
		end
		local purchased = item:clone()
		player.currency = player.currency - entry.cost
		target_die:addItem(purchased)
		table.remove(self.items_inventory, item_index)
		return true, "Die Mod applied!"
	end

	local purchased = item.clone and item:clone() or item
	player.currency = player.currency - entry.cost
	player:addItem(purchased)
	table.remove(self.items_inventory, item_index)
	return true, "Relic purchased!"
end

function Shop:buySticker(player, entry_index, die_index)
	local entry = self.items_inventory[entry_index]
	if not entry or entry.kind ~= "sticker" then
		return false, "Invalid sticker"
	end
	local die = player.dice_pool[die_index]
	if not die then
		return false, "Invalid die"
	end
	if player.currency < entry.cost then
		return false, "Not enough currency"
	end
	local ok, err = die:addSticker(entry.data, 1)
	if not ok then
		return false, err or "Cannot apply sticker"
	end
	player.currency = player.currency - entry.cost
	table.remove(self.items_inventory, entry_index)
	return true, "Sticker applied!"
end

return Shop
