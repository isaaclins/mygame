local Class = require("objects/class")
local Item = Class:extend()

function Item:init(opts)
	opts = opts or {}
	self.name = opts.name or "Unknown Item"
	self.description = opts.description or ""
	self.effect = opts.effect or function() end
	self.trigger_type = opts.trigger_type or "passive"
	self.icon = opts.icon or "?"
	self.cost = opts.cost or 10
	self.consumable = opts.consumable or false
	self.target_scope = opts.target_scope or "personal"
	self.targeting = opts.targeting
	self.condition = opts.condition
	self.dynamic_cost = opts.dynamic_cost
	self.triggered_this_round = opts.triggered_this_round or false
end

function Item:apply(context)
	if self.trigger_type == "once" and self.triggered_this_round then
		return
	end
	self.effect(self, context)
	if self.trigger_type == "once" then
		self.triggered_this_round = true
	end
end

function Item:resetRound()
	self.triggered_this_round = false
end

function Item:isDiceScoped()
	return self.target_scope == "dice"
end

function Item:clone()
	return Item:new({
		name = self.name,
		description = self.description,
		effect = self.effect,
		trigger_type = self.trigger_type,
		icon = self.icon,
		cost = self.cost,
		consumable = self.consumable,
		target_scope = self.target_scope,
		targeting = self.targeting,
		condition = self.condition,
		dynamic_cost = self.dynamic_cost,
		triggered_this_round = self.triggered_this_round,
	})
end

return Item
