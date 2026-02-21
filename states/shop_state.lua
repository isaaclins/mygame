local UI = require("functions/ui")
local Shop = require("objects/shop")
local Fonts = require("functions/fonts")

local ShopState = {}

local shop = nil
local message = ""
local message_timer = 0
local replacing_die = nil
local selected_shop_die = nil

local die_colors_map = {
    black = UI.colors.die_black,
    blue  = UI.colors.die_blue,
    green = UI.colors.die_green,
    red   = UI.colors.die_red,
}

function ShopState:init(player, all_dice_types, all_items)
    shop = Shop:new()
    shop:generate(player, all_dice_types, all_items)
    message = ""
    message_timer = 0
    replacing_die = nil
    selected_shop_die = nil
end

function ShopState:update(dt)
    message_timer = math.max(0, message_timer - dt)
end

function ShopState:draw(player)
    local W, H = love.graphics.getDimensions()

    UI.setColor(UI.colors.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)

    self:drawHeader(player, W)
    self:drawPlayerDice(player, W, H)
    self:drawHandUpgrades(player, W, H)
    self:drawDiceSection(player, W, H)
    self:drawItemsSection(player, W, H)
    self:drawContinueButton(W, H)

    if replacing_die then
        self:drawDieReplaceOverlay(player, W, H)
    end

    if message_timer > 0 then
        local alpha = math.min(1, message_timer)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setFont(Fonts.get(18))
        love.graphics.printf(message, 0, H - 70, W, "center")
    end
end

function ShopState:drawHeader(player, W)
    UI.drawPanel(10, 10, W - 20, 50)

    love.graphics.setFont(Fonts.get(22))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("SHOP", 0, 20, W, "center")

    UI.setColor(UI.colors.green)
    love.graphics.printf("$" .. player.currency, 0, 22, W - 24, "right")

    if not shop.free_choice_used then
        UI.drawBadge("FREE CHOICE AVAILABLE", 24, 22, UI.colors.free_badge, Fonts.get(14))
    end
end

function ShopState:drawPlayerDice(player, W, H)
    local die_size = 60
    local gap = 12
    local total = #player.dice_pool * die_size + (#player.dice_pool - 1) * gap
    local start_x = (W - total) / 2
    local die_y = 72

    for i, die in ipairs(player.dice_pool) do
        local dx = start_x + (i - 1) * (die_size + gap)
        local dot_color = die_colors_map[die.color] or UI.colors.die_black
        UI.drawDie(dx, die_y, die_size, die.value, dot_color, nil, false, false, die.glow_color)
        love.graphics.setFont(Fonts.get(11))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(die.name, dx - 5, die_y + die_size + 3, die_size + 10, "center")
    end
end

function ShopState:drawHandUpgrades(player, W, H)
    local section_x = 20
    local section_y = 160
    local section_w = W / 3 - 30
    local section_h = H - 250

    UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

    love.graphics.setFont(Fonts.get(18))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("HAND UPGRADES", section_x, section_y + 10, section_w, "center")

    self._hand_upgrade_buttons = {}
    local mx, my = love.mouse.getPosition()

    for i, upgrade in ipairs(shop.hand_upgrades) do
        local iy = section_y + 40 + (i - 1) * 58
        if iy + 50 > section_y + section_h then break end

        local maxed = upgrade.hand.upgrade_level >= upgrade.hand.max_upgrade
        local live_cost = upgrade.hand:getUpgradeCost()
        local item_x = section_x + 10
        local item_w = section_w - 20
        local hovered = not maxed and UI.pointInRect(mx, my, item_x, iy, item_w, 50)

        UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        UI.roundRect("fill", item_x, iy, item_w, 50, 6)

        love.graphics.setFont(Fonts.get(14))
        if maxed then
            UI.setColor(UI.colors.text_dark)
            love.graphics.print(upgrade.hand.name .. " MAX", item_x + 8, iy + 6)
        else
            UI.setColor(UI.colors.text)
            love.graphics.print(upgrade.hand.name .. " +" .. (upgrade.hand.upgrade_level + 1), item_x + 8, iy + 6)
        end

        love.graphics.setFont(Fonts.get(12))
        UI.setColor(UI.colors.text_dim)
        love.graphics.print(upgrade.hand:getDisplayScore(), item_x + 8, iy + 26)

        if maxed then
            UI.setColor(UI.colors.text_dark)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("MAXED", item_x, iy + 8, item_w - 8, "right")
        elseif not shop.free_choice_used then
            UI.setColor(UI.colors.free_badge)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("FREE", item_x, iy + 8, item_w - 8, "right")
        else
            local can_afford = player.currency >= live_cost
            UI.setColor(can_afford and UI.colors.accent or UI.colors.red)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("$" .. live_cost, item_x, iy + 8, item_w - 8, "right")
        end

        self._hand_upgrade_buttons[i] = { x = item_x, y = iy, w = item_w, h = 50, hovered = hovered }
    end

    if #shop.hand_upgrades == 0 then
        love.graphics.setFont(Fonts.get(12))
        UI.setColor(UI.colors.text_dark)
        love.graphics.printf("All hands maxed!", section_x, section_y + 60, section_w, "center")
    end
end

function ShopState:drawDiceSection(player, W, H)
    local section_x = W / 3 + 5
    local section_y = 160
    local section_w = W / 3 - 30
    local section_h = H - 250

    UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

    love.graphics.setFont(Fonts.get(18))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("DICE", section_x, section_y + 10, section_w, "center")

    self._dice_buttons = {}
    local mx, my = love.mouse.getPosition()

    for i, entry in ipairs(shop.dice_inventory) do
        local iy = section_y + 40 + (i - 1) * 80
        if iy + 72 > section_y + section_h then break end

        local item_x = section_x + 10
        local item_w = section_w - 20
        local hovered = UI.pointInRect(mx, my, item_x, iy, item_w, 72)

        UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        UI.roundRect("fill", item_x, iy, item_w, 72, 6)

        local die = entry.die
        local die_size = 40
        local dot_color = die_colors_map[die.color] or UI.colors.die_black
        UI.drawDie(item_x + 8, iy + 8, die_size, die.value, dot_color, nil, false, false, die.glow_color)

        love.graphics.setFont(Fonts.get(14))
        UI.setColor(UI.colors.text)
        love.graphics.print(die.name, item_x + 56, iy + 6)

        love.graphics.setFont(Fonts.get(11))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(die.ability_desc, item_x + 56, iy + 24, item_w - 64)

        if not shop.free_choice_used then
            UI.setColor(UI.colors.free_badge)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("FREE", item_x, iy + 8, item_w - 8, "right")
        else
            UI.setColor(UI.colors.accent)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("$" .. entry.cost, item_x, iy + 8, item_w - 8, "right")
        end

        self._dice_buttons[i] = { x = item_x, y = iy, w = item_w, h = 72, hovered = hovered }
    end

    if #shop.dice_inventory == 0 then
        love.graphics.setFont(Fonts.get(12))
        UI.setColor(UI.colors.text_dark)
        love.graphics.printf("No dice available", section_x, section_y + 60, section_w, "center")
    end
end

function ShopState:drawItemsSection(player, W, H)
    local section_x = 2 * W / 3 + 10
    local section_y = 160
    local section_w = W / 3 - 30
    local section_h = H - 250

    UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

    love.graphics.setFont(Fonts.get(18))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("ITEMS", section_x, section_y + 10, section_w, "center")

    self._item_buttons = {}
    local mx, my = love.mouse.getPosition()

    for i, item in ipairs(shop.items_inventory) do
        local iy = section_y + 40 + (i - 1) * 68
        if iy + 60 > section_y + section_h then break end

        local item_x = section_x + 10
        local item_w = section_w - 20
        local hovered = UI.pointInRect(mx, my, item_x, iy, item_w, 60)

        UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        UI.roundRect("fill", item_x, iy, item_w, 60, 6)

        love.graphics.setFont(Fonts.get(14))
        UI.setColor(UI.colors.text)
        love.graphics.print("[" .. item.icon .. "] " .. item.name, item_x + 8, iy + 6)

        love.graphics.setFont(Fonts.get(11))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(item.description, item_x + 8, iy + 26, item_w - 16)

        UI.setColor(UI.colors.accent)
        love.graphics.setFont(Fonts.get(14))
        love.graphics.printf("$" .. item.cost, item_x, iy + 8, item_w - 8, "right")

        self._item_buttons[i] = { x = item_x, y = iy, w = item_w, h = 60, hovered = hovered }
    end

    if #shop.items_inventory == 0 then
        love.graphics.setFont(Fonts.get(12))
        UI.setColor(UI.colors.text_dark)
        love.graphics.printf("No items available", section_x, section_y + 60, section_w, "center")
    end

    if #player.items > 0 then
        love.graphics.setFont(Fonts.get(12))
        local owned_y = section_y + section_h - 20 - #player.items * 16
        UI.setColor(UI.colors.text_dim)
        love.graphics.print("Owned:", section_x + 14, owned_y)
        for i, item in ipairs(player.items) do
            love.graphics.print("  [" .. item.icon .. "] " .. item.name, section_x + 14, owned_y + i * 16)
        end
    end
end

function ShopState:drawContinueButton(W, H)
    local btn_w, btn_h = 220, 52
    self._continue_hovered = UI.drawButton(
        "CONTINUE", (W - btn_w) / 2, H - 70, btn_w, btn_h,
        { font = Fonts.get(22), color = UI.colors.green, hover_color = { 0.25, 0.85, 0.45, 1 } }
    )
end

function ShopState:drawDieReplaceOverlay(player, W, H)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local panel_w, panel_h = 500, 180
    local px = (W - panel_w) / 2
    local py = (H - panel_h) / 2

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent })

    love.graphics.setFont(Fonts.get(20))
    UI.setColor(UI.colors.text)
    love.graphics.printf("Replace which die?", px, py + 15, panel_w, "center")

    local die_size = 65
    local gap = 16
    local total = #player.dice_pool * die_size + (#player.dice_pool - 1) * gap
    local start_x = px + (panel_w - total) / 2
    local die_y = py + 55

    local mx, my = love.mouse.getPosition()
    self._replace_die_buttons = {}

    for i, die in ipairs(player.dice_pool) do
        local dx = start_x + (i - 1) * (die_size + gap)
        local hovered = UI.pointInRect(mx, my, dx, die_y, die_size, die_size)
        local dot_color = die_colors_map[die.color] or UI.colors.die_black
        UI.drawDie(dx, die_y, die_size, die.value, dot_color, nil, false, hovered, die.glow_color)
        self._replace_die_buttons[i] = { x = dx, y = die_y, w = die_size, h = die_size }

        love.graphics.setFont(Fonts.get(10))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(die.name, dx - 5, die_y + die_size + 3, die_size + 10, "center")
    end

    self._cancel_replace_hovered = UI.drawButton(
        "CANCEL", px + panel_w / 2 - 60, py + panel_h - 40, 120, 32,
        { font = Fonts.get(16), color = UI.colors.red }
    )
end

function ShopState:mousepressed(x, y, button, player)
    if button ~= 1 then return nil end

    if replacing_die then
        for i, btn in pairs(self._replace_die_buttons or {}) do
            if UI.pointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
                local ok, msg = shop:buyDie(player, selected_shop_die, i)
                message = msg
                message_timer = 2.0
                replacing_die = false
                selected_shop_die = nil
                return nil
            end
        end
        if self._cancel_replace_hovered then
            replacing_die = false
            selected_shop_die = nil
            return nil
        end
        return nil
    end

    for i, btn in pairs(self._hand_upgrade_buttons or {}) do
        if btn.hovered then
            local ok, msg = shop:buyHandUpgrade(player, i)
            message = msg
            message_timer = 2.0
            return nil
        end
    end

    for i, btn in pairs(self._dice_buttons or {}) do
        if btn.hovered then
            replacing_die = true
            selected_shop_die = i
            return nil
        end
    end

    for i, btn in pairs(self._item_buttons or {}) do
        if btn.hovered then
            local ok, msg = shop:buyItem(player, i)
            message = msg
            message_timer = 2.0
            return nil
        end
    end

    if self._continue_hovered then
        return "next_round"
    end

    return nil
end

function ShopState:keypressed(key)
    if key == "return" or key == "space" then
        if not replacing_die then
            return "next_round"
        end
    elseif key == "escape" then
        if replacing_die then
            replacing_die = false
            selected_shop_die = nil
        end
    end
    return nil
end

return ShopState
