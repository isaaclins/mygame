local Class = require("objects/class")
local Sticker = Class:extend()

function Sticker:init(opts)
	opts = opts or {}
	self.id = opts.id or "unknown_sticker"
	self.name = opts.name or "Unknown Sticker"
	self.description = opts.description or ""
	self.stack_limit = opts.stack_limit or 1
	self.stackable = opts.stackable == true
	self.rarity = opts.rarity or "common"
	self.svg_path = opts.svg_path or ""
	self.effect_hooks = opts.effect_hooks or {}
	self.icon = opts.icon or "ST"
	self.schema_version = opts.schema_version or 1
end

function Sticker:isStackable()
	return self.stackable and self.stack_limit ~= 1
end

function Sticker:getStackLabel()
	if not self:isStackable() then
		return "UNSTACKABLE"
	end
	if self.stack_limit >= 9999 then
		return "INFINITE STACKABLE"
	end
	return tostring(self.stack_limit) .. "x STACKABLE"
end

function Sticker:clone()
	return Sticker:new({
		id = self.id,
		name = self.name,
		description = self.description,
		stack_limit = self.stack_limit,
		stackable = self.stackable,
		rarity = self.rarity,
		svg_path = self.svg_path,
		effect_hooks = { unpack(self.effect_hooks or {}) },
		icon = self.icon,
		schema_version = self.schema_version,
	})
end

return Sticker
