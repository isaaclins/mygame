local Class = require("objects/class")
local RNG = require("functions/rng")
local Die = Class:extend()

function Die:init(opts)
	opts = opts or {}
	self.name = opts.name or "Normal Die"
	self.color = opts.color or "black"
	self.value = opts.value or 1
	self.locked = false
	self.ability = opts.ability or nil
	self.ability_name = opts.ability_name or "None"
	self.ability_desc = opts.ability_desc or ""
	self.upgrade_level = opts.upgrade_level or 0
	self.max_upgrade = opts.max_upgrade or 3
	self.die_type = opts.die_type or "Normal"
	self.roll_timer = 0
	self.rolling = false
	self.glow_color = opts.glow_color or nil
	self.items = opts.items or {}

	self.weights = opts.weights or { 1, 1, 1, 1, 1, 1 }
	self.stickers = opts.stickers or {}
	self._sticker_state = opts._sticker_state or {}
end

function Die:addItem(item)
	table.insert(self.items, item)
end

function Die:removeItem(index)
	if index >= 1 and index <= #self.items then
		table.remove(self.items, index)
		return true
	end
	return false
end

function Die:applyItems(context)
	for _, item in ipairs(self.items) do
		item:apply(context)
	end
end

function Die:roll()
	if self.locked then
		return self.value
	end

	if self.die_type == "wild" then
		self.value = self.wild_choice or RNG.random(1, 6)
		return self.value
	end

	local total = 0
	for _, w in ipairs(self.weights) do
		total = total + w
	end
	local r = RNG.random() * total
	local cumulative = 0
	for i, w in ipairs(self.weights) do
		cumulative = cumulative + w
		if r <= cumulative then
			self.value = i
			break
		end
	end

	return self.value
end

function Die:startRoll(duration)
	self.rolling = true
	self.roll_timer = duration or 0.5
end

function Die:updateRoll(dt)
	if not self.rolling then
		return false
	end
	self.roll_timer = self.roll_timer - dt
	if self.roll_timer <= 0 then
		self.rolling = false
		self:roll()
		return true
	end
	if self.die_type == "light" then
		self.value = math.random(1, 3)
	elseif self.die_type == "heavy" then
		self.value = math.random(3, 6)
	elseif self.die_type == "broken" then
		self.value = 1
	else
		self.value = math.random(1, 6)
	end
	return false
end

function Die:toggleLock()
	self.locked = not self.locked
end

function Die:triggerAbility(context)
	if not self.ability then
		return nil
	end
	return self.ability(self, context)
end

function Die:upgrade()
	if self.upgrade_level >= self.max_upgrade then
		return false
	end
	self.upgrade_level = self.upgrade_level + 1
	return true
end

function Die:clone()
	local copied_items = {}
	for _, item in ipairs(self.items or {}) do
		if item.clone then
			table.insert(copied_items, item:clone())
		end
	end
	return Die:new({
		name = self.name,
		color = self.color,
		ability = self.ability,
		ability_name = self.ability_name,
		ability_desc = self.ability_desc,
		upgrade_level = self.upgrade_level,
		max_upgrade = self.max_upgrade,
		die_type = self.die_type,
		weights = { unpack(self.weights) },
		glow_color = self.glow_color,
		items = copied_items,
		stickers = self:getSerializedStickers(),
	})
end

function Die:getSticker(id)
	return self.stickers and self.stickers[id] or nil
end

function Die:getStickerStacks(id)
	local st = self:getSticker(id)
	return st and (st.stacks or 0) or 0
end

function Die:getDistinctStickerCount()
	local count = 0
	for _, st in pairs(self.stickers or {}) do
		if (st.stacks or 0) > 0 then
			count = count + 1
		end
	end
	return count
end

function Die:hasSticker(id)
	return self:getStickerStacks(id) > 0
end

function Die:_getEffectiveStackLimit(sticker_def)
	local id = sticker_def.id
	if id ~= "all_in" and self:hasSticker("all_in") then
		return math.huge
	end
	if sticker_def.stackable then
		return sticker_def.stack_limit or 1
	end
	return 1
end

function Die:canAddSticker(sticker_def, requested_stacks)
	if not sticker_def or not sticker_def.id then
		return false, "Invalid sticker"
	end
	requested_stacks = requested_stacks or 1
	if requested_stacks < 1 then
		return false, "Invalid stack amount"
	end

	local id = sticker_def.id
	local existing = self:getSticker(id)
	local distinct = self:getDistinctStickerCount()

	if not existing and distinct >= 5 then
		return false, "Max 5 different stickers per die"
	end

	local has_all_in = self:hasSticker("all_in")
	if id == "all_in" then
		local non_all_in = 0
		for sid, st in pairs(self.stickers or {}) do
			if sid ~= "all_in" and (st.stacks or 0) > 0 then
				non_all_in = non_all_in + 1
			end
		end
		if non_all_in > 1 then
			return false, "All In needs at most one other sticker type"
		end
	elseif has_all_in and not existing then
		local non_all_in = 0
		for sid, st in pairs(self.stickers or {}) do
			if sid ~= "all_in" and (st.stacks or 0) > 0 then
				non_all_in = non_all_in + 1
			end
		end
		if non_all_in >= 1 then
			return false, "All In allows only one other sticker type"
		end
	end

	local limit = self:_getEffectiveStackLimit(sticker_def)
	local current = existing and (existing.stacks or 0) or 0
	if current + requested_stacks > limit then
		return false, "Sticker stack limit reached"
	end
	return true, nil
end

function Die:addSticker(sticker_def, stacks)
	stacks = stacks or 1
	local ok, err = self:canAddSticker(sticker_def, stacks)
	if not ok then
		return false, err
	end

	local id = sticker_def.id
	local st = self.stickers[id]
	if not st then
		local ox = (RNG.random() * 0.24) - 0.12
		local oy = (RNG.random() * 0.24) - 0.12
		-- Avoid perfectly centered stickers so they read as "applied decal."
		if math.abs(ox) < 0.03 and math.abs(oy) < 0.03 then
			ox = (ox >= 0 and 0.05 or -0.05)
			oy = (oy >= 0 and 0.05 or -0.05)
		end
		st = {
			id = id,
			name = sticker_def.name,
			description = sticker_def.description,
			rarity = sticker_def.rarity,
			svg_path = sticker_def.svg_path,
			stack_limit = sticker_def.stack_limit,
			stackable = sticker_def.stackable,
			stacks = 0,
			angle = (RNG.random() * 40) - 20,
			offset_x = ox,
			offset_y = oy,
			scale = 0.25 + RNG.random() * 0.5,
		}
		self.stickers[id] = st
	end
	st.stacks = st.stacks + stacks
	return true, st.stacks
end

function Die:removeSticker(id, stacks)
	stacks = stacks or 1
	local st = self.stickers[id]
	if not st then
		return false
	end
	st.stacks = math.max(0, (st.stacks or 0) - stacks)
	if st.stacks == 0 then
		self.stickers[id] = nil
	end
	return true
end

function Die:getSerializedStickers()
	local out = {}
	for id, st in pairs(self.stickers or {}) do
		if (st.stacks or 0) > 0 then
			out[id] = {
				id = id,
				name = st.name,
				description = st.description,
				rarity = st.rarity,
				svg_path = st.svg_path,
				stack_limit = st.stack_limit,
				stackable = st.stackable,
				stacks = st.stacks,
				angle = st.angle,
				offset_x = st.offset_x,
				offset_y = st.offset_y,
				scale = st.scale,
			}
		end
	end
	return out
end

function Die:getDescription()
	local desc = self.name
	if self.ability_name ~= "None" then
		desc = desc .. " [" .. self.ability_name .. "]"
	end
	if self.upgrade_level > 0 then
		desc = desc .. " +" .. self.upgrade_level
	end
	return desc
end

return Die
