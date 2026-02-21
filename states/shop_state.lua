local UI = require("functions/ui")
local Shop = require("objects/shop")
local Fonts = require("functions/fonts")
local Tween = require("functions/tween")
local Particles = require("functions/particles")
local Toast = require("functions/toast")

local ShopState = {}

local shop = nil
local replacing_die = nil
local selected_shop_die = nil

local section_anims = {}
local currency_anim = { display = 0 }
local card_hovers = {}

local die_colors_map = {
    black = UI.colors.die_black,
    blue  = UI.colors.die_blue,
    green = UI.colors.die_green,
    red   = UI.colors.die_red,
}

function ShopState:init(player, all_dice_types, all_items)
    shop = Shop:new()
    shop:generate(player, all_dice_types, all_items)
    replacing_die = nil
    selected_shop_die = nil
    card_hovers = {}

    currency_anim = { display = player.currency }

    section_anims = {}
    for i = 1, 3 do
        section_anims[i] = { y_off = 60, alpha = 0 }
        Tween.to(section_anims[i], 0.4, { y_off = 0, alpha = 1 }, "outBack")
    end
end

function ShopState:update(dt)
    for key, ch in pairs(card_hovers) do
        ch.lift = ch.lift + (ch.target_lift - ch.lift) * math.min(1, 12 * dt)
        ch.shadow = ch.shadow + (ch.target_shadow - ch.shadow) * math.min(1, 12 * dt)
    end
end

local function getCardHover(key)
    if not card_hovers[key] then
        card_hovers[key] = { lift = 0, target_lift = 0, shadow = 0, target_shadow = 0 }
    end
    return card_hovers[key]
end

local function setCardHoverState(key, hovered)
    local ch = getCardHover(key)
    ch.target_lift = hovered and -4 or 0
    ch.target_shadow = hovered and 6 or 0
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

end

function ShopState:drawHeader(player, W)
    UI.drawPanel(10, 10, W - 20, 50)

    love.graphics.setFont(Fonts.get(22))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("SHOP", 0, 20, W, "center")

    currency_anim.display = currency_anim.display + (player.currency - currency_anim.display) * math.min(1, 8 * love.timer.getDelta())
    UI.setColor(UI.colors.green)
    love.graphics.printf("$" .. math.floor(currency_anim.display + 0.5), 0, 22, W - 24, "right")

    if not shop.free_choice_used then
        UI.drawBadge("FREE CHOICE AVAILABLE", 24, 22, UI.colors.free_badge, Fonts.get(14), true)
    end
end

function ShopState:drawPlayerDice(player, W, H)
    local count = #player.dice_pool
    local max_total = W * 0.7
    local die_size = math.min(60, math.floor((max_total - (count - 1) * 8) / count))
    local gap = math.min(12, math.floor((max_total - count * die_size) / math.max(count - 1, 1)))
    local total = count * die_size + (count - 1) * gap
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
    local sa = section_anims[1] or { y_off = 0, alpha = 1 }
    local section_x = 20
    local section_y = 160 + sa.y_off
    local section_w = W / 3 - 30
    local section_h = H - 250

    love.graphics.setColor(1, 1, 1, sa.alpha)
    UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

    love.graphics.setFont(Fonts.get(18))
    love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
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

        local key = "hand_" .. i
        setCardHoverState(key, hovered)
        local ch = getCardHover(key)

        UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        if ch.shadow > 0.5 then
            love.graphics.setColor(0, 0, 0, 0.15)
            UI.roundRect("fill", item_x + 2, iy + ch.shadow + 2, item_w, 50, 6)
        end
        UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        UI.roundRect("fill", item_x, iy + ch.lift, item_w, 50, 6)

        love.graphics.setFont(Fonts.get(14))
        if maxed then
            UI.setColor(UI.colors.text_dark)
            love.graphics.print(upgrade.hand.name .. " MAX", item_x + 8, iy + 6 + ch.lift)
        else
            UI.setColor(UI.colors.text)
            love.graphics.print(upgrade.hand.name .. " +" .. (upgrade.hand.upgrade_level + 1), item_x + 8, iy + 6 + ch.lift)
        end

        love.graphics.setFont(Fonts.get(12))
        UI.setColor(UI.colors.text_dim)
        love.graphics.print(upgrade.hand:getDisplayScore(), item_x + 8, iy + 26 + ch.lift)

        if maxed then
            UI.setColor(UI.colors.text_dark)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("MAXED", item_x, iy + 8 + ch.lift, item_w - 8, "right")
        elseif not shop.free_choice_used then
            UI.setColor(UI.colors.free_badge)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("FREE", item_x, iy + 8 + ch.lift, item_w - 8, "right")
        else
            local can_afford = player.currency >= live_cost
            UI.setColor(can_afford and UI.colors.accent or UI.colors.red)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("$" .. live_cost, item_x, iy + 8 + ch.lift, item_w - 8, "right")
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
    local sa = section_anims[2] or { y_off = 0, alpha = 1 }
    local section_x = W / 3 + 5
    local section_y = 160 + sa.y_off
    local section_w = W / 3 - 30
    local section_h = H - 250

    love.graphics.setColor(1, 1, 1, sa.alpha)
    UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

    love.graphics.setFont(Fonts.get(18))
    love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
    love.graphics.printf("DICE", section_x, section_y + 10, section_w, "center")

    self._dice_buttons = {}
    local mx, my = love.mouse.getPosition()

    for i, entry in ipairs(shop.dice_inventory) do
        local iy = section_y + 40 + (i - 1) * 80
        if iy + 72 > section_y + section_h then break end

        local item_x = section_x + 10
        local item_w = section_w - 20
        local hovered = UI.pointInRect(mx, my, item_x, iy, item_w, 72)

        local key = "dice_" .. i
        setCardHoverState(key, hovered)
        local ch = getCardHover(key)

        if ch.shadow > 0.5 then
            love.graphics.setColor(0, 0, 0, 0.15)
            UI.roundRect("fill", item_x + 2, iy + ch.shadow + 2, item_w, 72, 6)
        end
        UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        UI.roundRect("fill", item_x, iy + ch.lift, item_w, 72, 6)

        local die = entry.die
        local die_size = 40
        local dot_color = die_colors_map[die.color] or UI.colors.die_black
        UI.drawDie(item_x + 8, iy + 8 + ch.lift, die_size, die.value, dot_color, nil, false, false, die.glow_color)

        love.graphics.setFont(Fonts.get(14))
        UI.setColor(UI.colors.text)
        love.graphics.print(die.name, item_x + 56, iy + 6 + ch.lift)

        love.graphics.setFont(Fonts.get(11))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(die.ability_desc, item_x + 56, iy + 24 + ch.lift, item_w - 64)

        if not shop.free_choice_used then
            UI.setColor(UI.colors.free_badge)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("FREE", item_x, iy + 8 + ch.lift, item_w - 8, "right")
        else
            UI.setColor(UI.colors.accent)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("$" .. entry.cost, item_x, iy + 8 + ch.lift, item_w - 8, "right")
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
    local sa = section_anims[3] or { y_off = 0, alpha = 1 }
    local section_x = 2 * W / 3 + 10
    local section_y = 160 + sa.y_off
    local section_w = W / 3 - 30
    local section_h = H - 250

    love.graphics.setColor(1, 1, 1, sa.alpha)
    UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

    love.graphics.setFont(Fonts.get(18))
    love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
    love.graphics.printf("ITEMS", section_x, section_y + 10, section_w, "center")

    self._item_buttons = {}
    local mx, my = love.mouse.getPosition()

    for i, item in ipairs(shop.items_inventory) do
        local iy = section_y + 40 + (i - 1) * 68
        if iy + 60 > section_y + section_h then break end

        local item_x = section_x + 10
        local item_w = section_w - 20
        local hovered = UI.pointInRect(mx, my, item_x, iy, item_w, 60)

        local key = "item_" .. i
        setCardHoverState(key, hovered)
        local ch = getCardHover(key)

        if ch.shadow > 0.5 then
            love.graphics.setColor(0, 0, 0, 0.15)
            UI.roundRect("fill", item_x + 2, iy + ch.shadow + 2, item_w, 60, 6)
        end
        UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        UI.roundRect("fill", item_x, iy + ch.lift, item_w, 60, 6)

        love.graphics.setFont(Fonts.get(14))
        UI.setColor(UI.colors.text)
        love.graphics.print("[" .. item.icon .. "] " .. item.name, item_x + 8, iy + 6 + ch.lift)

        love.graphics.setFont(Fonts.get(11))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(item.description, item_x + 8, iy + 26 + ch.lift, item_w - 16)

        UI.setColor(UI.colors.accent)
        love.graphics.setFont(Fonts.get(14))
        love.graphics.printf("$" .. item.cost, item_x, iy + 8 + ch.lift, item_w - 8, "right")

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
        { font = Fonts.get(22), color = UI.colors.green, hover_color = UI.colors.green_light }
    )
end

function ShopState:drawDieReplaceOverlay(player, W, H)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local count = #player.dice_pool
    local die_size = math.min(65, math.floor((W * 0.55 - (count - 1) * 10) / count))
    local gap = math.min(16, math.floor(die_size * 0.2))
    local total = count * die_size + (count - 1) * gap
    local panel_w = math.max(500, total + 60)
    local panel_h = die_size + 120
    local px = (W - panel_w) / 2
    local py = (H - panel_h) / 2

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent })

    love.graphics.setFont(Fonts.get(20))
    UI.setColor(UI.colors.text)
    love.graphics.printf("Replace which die?", px, py + 15, panel_w, "center")

    local start_x = px + (panel_w - total) / 2
    local die_y = py + 50

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
                if ok then
                    Toast.success(msg)
                    Particles.sparkle(x, y, UI.colors.green_light, 15)
                else
                    Toast.error(msg)
                end
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
            if ok then
                Toast.success(msg)
                Particles.sparkle(x, y, UI.colors.accent, 12)
            else
                Toast.error(msg)
            end
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
            if ok then
                Toast.success(msg)
                Particles.sparkle(x, y, UI.colors.green_light, 15)
            else
                Toast.error(msg)
            end
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
