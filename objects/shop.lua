local Class = require("objects/class")
local RNG = require("functions/rng")
local Shop = Class:extend()

function Shop:init()
    self.hand_upgrades = {}
    self.dice_inventory = {}
    self.items_inventory = {}
    self.free_choice_used = false
    self.selected_section = 1
end

function Shop:generate(player, all_dice_types, all_items)
    self.free_choice_used = player.free_choice_used

    self.hand_upgrades = {}
    local dice_count = #player.dice_pool
    for i, hand in ipairs(player.hands) do
        if hand.upgrade_level < hand.max_upgrade and (hand.min_dice or 1) <= dice_count then
            table.insert(self.hand_upgrades, {
                hand_index = i,
                hand = hand,
                cost = hand:getUpgradeCost(),
            })
        end
    end

    self.dice_inventory = {}
    local available = {}
    for _, dt in ipairs(all_dice_types) do
        table.insert(available, dt)
    end
    for i = 1, math.min(3, #available) do
        local idx = RNG.random(1, #available)
        table.insert(self.dice_inventory, {
            die = available[idx]:clone(),
            cost = 8 + available[idx].upgrade_level * 4,
        })
        table.remove(available, idx)
    end

    self.items_inventory = {}
    local avail_items = {}
    for _, item in ipairs(all_items) do
        local owned = false
        for _, pi in ipairs(player.items) do
            if pi.name == item.name then
                owned = true
                break
            end
        end
        if not owned then
            table.insert(avail_items, item)
        end
    end
    for i = 1, math.min(3, #avail_items) do
        local idx = RNG.random(1, #avail_items)
        table.insert(self.items_inventory, avail_items[idx])
        table.remove(avail_items, idx)
    end
end

function Shop:buyHandUpgrade(player, upgrade_index)
    local upgrade = self.hand_upgrades[upgrade_index]
    if not upgrade then return false, "Invalid upgrade" end

    if upgrade.hand.upgrade_level >= upgrade.hand.max_upgrade then
        return false, "Already maxed!"
    end

    local live_cost = upgrade.hand:getUpgradeCost()

    if not self.free_choice_used then
        self.free_choice_used = true
        player.free_choice_used = true
        upgrade.hand:upgrade()
        upgrade.cost = upgrade.hand:getUpgradeCost()
        return true, "Free upgrade applied!"
    end

    if player.currency < live_cost then
        return false, "Not enough currency"
    end

    player.currency = player.currency - live_cost
    upgrade.hand:upgrade()
    upgrade.cost = upgrade.hand:getUpgradeCost()
    return true, "Upgrade purchased!"
end

function Shop:buyDie(player, shop_die_index, player_die_index)
    local shop_entry = self.dice_inventory[shop_die_index]
    if not shop_entry then return false, "Invalid die" end

    if not self.free_choice_used then
        self.free_choice_used = true
        player.free_choice_used = true
        player:replaceDie(player_die_index, shop_entry.die)
        table.remove(self.dice_inventory, shop_die_index)
        return true, "Free replacement!"
    end

    if player.currency < shop_entry.cost then
        return false, "Not enough currency"
    end

    player.currency = player.currency - shop_entry.cost
    player:replaceDie(player_die_index, shop_entry.die)
    table.remove(self.dice_inventory, shop_die_index)
    return true, "Die replaced!"
end

function Shop:buyItem(player, item_index)
    local item = self.items_inventory[item_index]
    if not item then return false, "Invalid item" end

    if player.currency < item.cost then
        return false, "Not enough currency"
    end

    if item.consumable then
        local result = item.effect(item, { player = player })
        if result == false then
            return false, "Cannot use (pool full?)"
        end
        player.currency = player.currency - item.cost
        table.remove(self.items_inventory, item_index)
        return true, "Die added to pool!"
    end

    player.currency = player.currency - item.cost
    player:addItem(item)
    table.remove(self.items_inventory, item_index)
    return true, "Item purchased!"
end

return Shop
