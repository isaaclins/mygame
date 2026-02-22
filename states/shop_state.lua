local UI = require("functions/ui")
local Shop = require("objects/shop")
local Fonts = require("functions/fonts")
local Tween = require("functions/tween")
local Particles = require("functions/particles")
local Toast = require("functions/toast")
local Settings = require("functions/settings")

local ShopState = {}

local hand_examples = {
    ["High Roll"]       = { 6 },
    ["Pair"]            = { 3, 3 },
    ["Two Pair"]        = { 2, 2, 5, 5 },
    ["Three of a Kind"] = { 4, 4, 4 },
    ["Small Straight"]  = { 2, 3, 4, 5 },
    ["Full House"]      = { 3, 3, 3, 6, 6 },
    ["Large Straight"]  = { 1, 2, 3, 4, 5 },
    ["Four of a Kind"]  = { 1, 1, 1, 1 },
    ["Five of a Kind"]  = { 5, 5, 5, 5, 5 },
    ["All Even"]        = { 2, 4, 6, 2, 4 },
    ["All Odd"]         = { 1, 3, 5, 1, 3 },
    ["Three Pairs"]     = { 1, 1, 3, 3, 5, 5 },
    ["Two Triplets"]    = { 2, 2, 2, 5, 5, 5 },
    ["Full Run"]        = { 1, 2, 3, 4, 5, 6 },
    ["Six of a Kind"]   = { 3, 3, 3, 3, 3, 3 },
    ["Seven of a Kind"] = { 6, 6, 6, 6, 6, 6, 6 },
    ["Pyramid"]         = { 2, 4, 4, 4, 6, 6, 6, 6, 6 },
}

local shop = nil
local replacing_die = nil
local selected_shop_die = nil

local section_anims = {}
local currency_anim = { display = 0 }
local card_hovers = {}

local MAX_DICE = 10
local BASE_EXTRA_DIE_COST = 15

local shop_col = 1
local shop_row = 1
local shop_mode = "grid"
local replace_focus = 1
local shop_visible_hands = {}

local function getColItemCount(col)
    if not shop then return 0 end
    if col == 1 then return #shop.dice_inventory
    elseif col == 2 then return #shop.items_inventory
    elseif col == 3 then return #shop_visible_hands
    end
    return 0
end

local function getExtraDieCost(player)
    local extra = math.max(0, #player.dice_pool - 5)
    return BASE_EXTRA_DIE_COST + extra * extra * 10
end

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
    shop_col = 1
    shop_row = 1
    shop_mode = "grid"
    replace_focus = 1

    local sort_mode = Settings.get("dice_sort_mode") or "default"
    player:sortDice(sort_mode)

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
    self:drawDiceSection(player, W, H)
    self:drawItemsSection(player, W, H)
    self:drawShopHandReference(player, W, H)
    self:drawContinueButton(W, H)

    if not replacing_die then
        love.graphics.setFont(Fonts.get(11))
        UI.setColor(UI.colors.text_dark)
        love.graphics.printf(
            "Arrows: Navigate  |  Enter: Select  |  Tab: Continue  |  Esc: Pause",
            0, H - 13, W, "center"
        )
    end

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
    local has_ghost = count < MAX_DICE
    local slot_count = has_ghost and (count + 1) or count
    local max_total = W * 0.7
    local die_size = math.min(60, math.floor((max_total - (slot_count - 1) * 8) / slot_count))
    local gap = math.min(12, math.floor((max_total - slot_count * die_size) / math.max(slot_count - 1, 1)))
    local total = slot_count * die_size + (slot_count - 1) * gap
    local start_x = (W - total) / 2
    local die_y = 80

    love.graphics.setFont(Fonts.get(12))
    UI.setColor(UI.colors.text_dim)
    love.graphics.printf("YOUR DICE", 0, 66, W, "center")

    for i, die in ipairs(player.dice_pool) do
        local dx = start_x + (i - 1) * (die_size + gap)
        local dot_color = die_colors_map[die.color] or UI.colors.die_black
        UI.drawDie(dx, die_y, die_size, die.value, dot_color, nil, false, false, die.glow_color)
        love.graphics.setFont(Fonts.get(10))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(die.name, dx - 5, die_y + die_size + 3, die_size + 10, "center")
    end

    if has_ghost then
        local gx = start_x + count * (die_size + gap)
        local gy = die_y
        local r = die_size * 0.15
        local mx, my = love.mouse.getPosition()
        local ghost_hovered = UI.pointInRect(mx, my, gx, gy, die_size, die_size)
        local cost = getExtraDieCost(player)
        local can_afford = player.currency >= cost

        local pulse = 0.5 + 0.15 * math.sin(love.timer.getTime() * 3)

        if ghost_hovered and can_afford then
            love.graphics.setColor(0.95, 0.93, 0.88, 0.25)
        else
            love.graphics.setColor(0.95, 0.93, 0.88, 0.10)
        end
        UI.roundRect("fill", gx, gy, die_size, die_size, r)

        love.graphics.setLineWidth(2)
        if ghost_hovered and can_afford then
            love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.7)
        else
            love.graphics.setColor(1, 1, 1, 0.15)
        end
        love.graphics.setLineStyle("smooth")
        local dash_len = 6
        local perimeter = 2 * (die_size + die_size)
        local segments = math.floor(perimeter / (dash_len * 2))
        UI.roundRect("line", gx, gy, die_size, die_size, r)
        love.graphics.setLineWidth(1)

        local plus_size = die_size * 0.22
        local cx = gx + die_size / 2
        local cy = gy + die_size / 2
        local plus_alpha = ghost_hovered and (can_afford and 0.6 or 0.3) or (0.2 + pulse * 0.1)
        love.graphics.setColor(1, 1, 1, plus_alpha)
        love.graphics.setLineWidth(math.max(2, die_size * 0.04))
        love.graphics.line(cx - plus_size, cy, cx + plus_size, cy)
        love.graphics.line(cx, cy - plus_size, cx, cy + plus_size)
        love.graphics.setLineWidth(1)

        love.graphics.setFont(Fonts.get(11))
        if can_afford then
            UI.setColor(UI.colors.accent)
        else
            UI.setColor(UI.colors.red)
        end
        love.graphics.printf("$" .. cost, gx - 5, gy + die_size + 3, die_size + 10, "center")

        self._ghost_die = { x = gx, y = gy, w = die_size, h = die_size, hovered = ghost_hovered, cost = cost }

        if shop_mode == "ghost" and not replacing_die then
            UI.drawFocusRect(gx, gy, die_size, die_size)
        end
    else
        self._ghost_die = nil
    end
end

function ShopState:drawShopHandReference(player, W, H)
    local sa = section_anims[3] or { y_off = 0, alpha = 1 }
    local section_x = 2 * W / 3 + 10
    local section_y = 160 + sa.y_off
    local section_w = W / 3 - 30
    local section_h = H - 250

    shop_visible_hands = {}
    local upgrade_index_map = {}
    for i, upgrade in ipairs(shop.hand_upgrades) do
        table.insert(shop_visible_hands, upgrade.hand)
        upgrade_index_map[upgrade.hand] = i
    end

    local count = #shop_visible_hands
    local header_h = 36
    local avail_h = section_h - header_h - 8
    local line_h = math.max(24, math.min(36, math.floor(avail_h / math.max(count, 1))))
    local name_font = line_h >= 30 and 13 or 11
    local stat_font = line_h >= 30 and 11 or 10

    love.graphics.setColor(1, 1, 1, sa.alpha)
    UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

    love.graphics.setFont(Fonts.get(18))
    love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
    love.graphics.printf("HAND TYPES", section_x, section_y + 10, section_w, "center")

    self._hand_ref_buttons = {}
    local mx, my = love.mouse.getPosition()
    local hovered_hand = nil
    local hovered_hand_y = 0

    for i, hand in ipairs(shop_visible_hands) do
        local y = section_y + header_h + (i - 1) * line_h
        if y + line_h > section_y + section_h then break end

        local maxed = hand.upgrade_level >= hand.max_upgrade
        local upgrade_idx = upgrade_index_map[hand]
        local can_upgrade = upgrade_idx and not maxed
        local can_afford = can_upgrade and (not shop.free_choice_used or player.currency >= hand:getUpgradeCost())
        local hovered = UI.pointInRect(mx, my, section_x + 4, y, section_w - 8, line_h)
        local is_focused = shop_mode == "grid" and shop_col == 3 and shop_row == i and not replacing_die

        if hovered or is_focused then
            love.graphics.setColor(1, 1, 1, 0.08 * sa.alpha)
            UI.roundRect("fill", section_x + 4, y, section_w - 8, line_h, 3)
            hovered_hand = hand
            hovered_hand_y = y
        end

        if can_afford then
            love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], 0.12 * sa.alpha)
            UI.roundRect("fill", section_x + 4, y, section_w - 8, line_h, 3)
        end

        if is_focused then
            UI.drawFocusRect(section_x + 4, y, section_w - 8, line_h)
        end

        love.graphics.setFont(Fonts.get(name_font))
        if can_afford then
            love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], sa.alpha)
        elseif can_upgrade and not can_afford then
            love.graphics.setColor(UI.colors.red[1], UI.colors.red[2], UI.colors.red[3], sa.alpha * 0.7)
        elseif hand.upgrade_level > 0 then
            love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
        elseif hovered or is_focused then
            love.graphics.setColor(1, 1, 1, sa.alpha)
        else
            love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], sa.alpha)
        end

        local name_text = hand.name
        if hand.upgrade_level > 0 then
            name_text = name_text .. " Lv." .. hand.upgrade_level
        end
        love.graphics.print(name_text, section_x + 10, y + 2)

        love.graphics.setFont(Fonts.get(stat_font))
        if can_upgrade then
            if not shop.free_choice_used then
                love.graphics.setColor(UI.colors.free_badge[1], UI.colors.free_badge[2], UI.colors.free_badge[3], sa.alpha)
                love.graphics.printf("FREE", section_x, y + 2, section_w - 10, "right")
            else
                local live_cost = hand:getUpgradeCost()
                local can_afford = player.currency >= live_cost
                if can_afford then
                    love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], sa.alpha)
                else
                    love.graphics.setColor(UI.colors.red[1], UI.colors.red[2], UI.colors.red[3], sa.alpha)
                end
                love.graphics.printf("$" .. live_cost, section_x, y + 2, section_w - 10, "right")
            end
        elseif maxed then
            love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], sa.alpha * 0.6)
            love.graphics.printf("MAX", section_x, y + 2, section_w - 10, "right")
        else
            love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], sa.alpha * 0.7)
            love.graphics.printf(hand:getDisplayScore(), section_x, y + 2, section_w - 10, "right")
        end

        local sub_y = y + 2 + (name_font + 2)
        if sub_y + stat_font < y + line_h then
            love.graphics.setFont(Fonts.get(stat_font))
            love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], sa.alpha * 0.8)
            love.graphics.printf(hand:getDisplayScore(), section_x + 10, sub_y, section_w - 20, "left")
            if can_upgrade then
                love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], sa.alpha * 0.5)
                love.graphics.printf("click to upgrade", section_x, sub_y, section_w - 10, "right")
            end
        end

        self._hand_ref_buttons[i] = {
            x = section_x + 4, y = y, w = section_w - 8, h = line_h,
            hovered = hovered, upgrade_idx = upgrade_idx, can_upgrade = can_upgrade,
        }
    end

    if hovered_hand then
        self:drawShopHandTooltip(hovered_hand, section_x, section_y, hovered_hand_y)
    end
end

function ShopState:drawShopHandTooltip(hand, ref_x, ref_y, row_y)
    local example = hand_examples[hand.name]
    if not example then return end

    local die_size = 28
    local die_gap = 6
    local dice_row_w = #example * die_size + (#example - 1) * die_gap
    local pad = 12
    local tip_w = math.max(dice_row_w + pad * 2, 180)
    local tip_h = die_size + pad * 2 + 52

    local tip_x = ref_x - tip_w - 8
    local tip_y = math.max(ref_y, math.min(row_y - tip_h / 2 + 12, love.graphics.getHeight() - tip_h - 10))

    love.graphics.setColor(0.08, 0.08, 0.16, 0.95)
    UI.roundRect("fill", tip_x, tip_y, tip_w, tip_h, 8)
    UI.setColor(UI.colors.accent)
    love.graphics.setLineWidth(1.5)
    UI.roundRect("line", tip_x, tip_y, tip_w, tip_h, 8)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(Fonts.get(13))
    UI.setColor(UI.colors.accent)
    love.graphics.printf(hand.name, tip_x, tip_y + 8, tip_w, "center")

    local dice_x = tip_x + (tip_w - dice_row_w) / 2
    local dice_y = tip_y + 28

    for i, val in ipairs(example) do
        local ddx = dice_x + (i - 1) * (die_size + die_gap)
        UI.drawDie(ddx, dice_y, die_size, val, UI.colors.die_black)
    end

    love.graphics.setFont(Fonts.get(11))
    UI.setColor(UI.colors.text_dim)
    love.graphics.printf(hand:getDisplayScore(), tip_x, tip_y + tip_h - 20, tip_w, "center")
end

function ShopState:drawDiceSection(player, W, H)
    local sa = section_anims[1] or { y_off = 0, alpha = 1 }
    local section_x = 20
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

        local entry_affordable = not shop.free_choice_used and true or player.currency >= entry.cost

        if ch.shadow > 0.5 then
            love.graphics.setColor(0, 0, 0, 0.15)
            UI.roundRect("fill", item_x + 2, iy + ch.shadow + 2, item_w, 72, 6)
        end
        if entry_affordable then
            UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        else
            local bg = UI.colors.panel_light
            love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * 0.5)
        end
        UI.roundRect("fill", item_x, iy + ch.lift, item_w, 72, 6)

        local die = entry.die
        local die_size = 40
        local can_afford = shop.free_choice_used == false or player.currency >= entry.cost
        local dim = (not can_afford) and 0.4 or 1.0
        local dot_color = die_colors_map[die.color] or UI.colors.die_black
        love.graphics.setColor(dot_color[1], dot_color[2], dot_color[3], dim)
        UI.drawDie(item_x + 8, iy + 8 + ch.lift, die_size, die.value, {dot_color[1], dot_color[2], dot_color[3], dim}, nil, false, false, die.glow_color)

        love.graphics.setFont(Fonts.get(14))
        love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], dim)
        love.graphics.print(die.name, item_x + 56, iy + 6 + ch.lift)

        love.graphics.setFont(Fonts.get(11))
        love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], dim)
        love.graphics.printf(die.ability_desc, item_x + 56, iy + 24 + ch.lift, item_w - 64)

        if not shop.free_choice_used then
            UI.setColor(UI.colors.free_badge)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("FREE", item_x, iy + 8 + ch.lift, item_w - 8, "right")
        else
            UI.setColor(can_afford and UI.colors.accent or UI.colors.red)
            love.graphics.setFont(Fonts.get(14))
            love.graphics.printf("$" .. entry.cost, item_x, iy + 8 + ch.lift, item_w - 8, "right")
        end

        self._dice_buttons[i] = { x = item_x, y = iy, w = item_w, h = 72, hovered = hovered }

        if shop_mode == "grid" and shop_col == 1 and shop_row == i and not replacing_die then
            UI.drawFocusRect(item_x, iy + ch.lift, item_w, 72)
        end
    end

    if #shop.dice_inventory == 0 then
        love.graphics.setFont(Fonts.get(12))
        UI.setColor(UI.colors.text_dark)
        love.graphics.printf("No dice available", section_x, section_y + 60, section_w, "center")
    end
end

function ShopState:drawItemsSection(player, W, H)
    local sa = section_anims[2] or { y_off = 0, alpha = 1 }
    local section_x = W / 3 + 5
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

        local can_afford = player.currency >= item.cost

        if ch.shadow > 0.5 then
            love.graphics.setColor(0, 0, 0, 0.15)
            UI.roundRect("fill", item_x + 2, iy + ch.shadow + 2, item_w, 60, 6)
        end
        if can_afford then
            UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
        else
            local bg = UI.colors.panel_light
            love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * 0.5)
        end
        UI.roundRect("fill", item_x, iy + ch.lift, item_w, 60, 6)
        local dim = can_afford and 1.0 or 0.4

        love.graphics.setFont(Fonts.get(14))
        love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], dim)
        love.graphics.print("[" .. item.icon .. "] " .. item.name, item_x + 8, iy + 6 + ch.lift)

        love.graphics.setFont(Fonts.get(11))
        love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], dim)
        love.graphics.printf(item.description, item_x + 8, iy + 26 + ch.lift, item_w - 16)

        UI.setColor(can_afford and UI.colors.accent or UI.colors.red)
        love.graphics.setFont(Fonts.get(14))
        love.graphics.printf("$" .. item.cost, item_x, iy + 8 + ch.lift, item_w - 8, "right")

        self._item_buttons[i] = { x = item_x, y = iy, w = item_w, h = 60, hovered = hovered }

        if shop_mode == "grid" and shop_col == 2 and shop_row == i and not replacing_die then
            UI.drawFocusRect(item_x, iy + ch.lift, item_w, 60)
        end
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
    if shop_mode == "continue" and not replacing_die then
        UI.drawFocusRect((W - btn_w) / 2, H - 70, btn_w, btn_h)
    end
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

        if replace_focus == i then
            UI.drawFocusRect(dx, die_y, die_size, die_size)
        end

        love.graphics.setFont(Fonts.get(10))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(die.name, dx - 5, die_y + die_size + 3, die_size + 10, "center")
    end

    self._cancel_replace_hovered = UI.drawButton(
        "CANCEL", px + panel_w / 2 - 60, py + panel_h - 40, 120, 32,
        { font = Fonts.get(16), color = UI.colors.red }
    )
    if replace_focus == 0 then
        UI.drawFocusRect(px + panel_w / 2 - 60, py + panel_h - 40, 120, 32)
    end
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

    if self._ghost_die and self._ghost_die.hovered then
        local cost = self._ghost_die.cost
        if #player.dice_pool >= MAX_DICE then
            Toast.error("Dice pool is full! (max " .. MAX_DICE .. ")")
        elseif player.currency < cost then
            Toast.error("Not enough currency! ($" .. cost .. " needed)")
        else
            player.currency = player.currency - cost
            local Die = require("objects/die")
            local new_die = Die:new({
                name = "Vanilla Die",
                color = "black",
                die_type = "vanilla",
                ability_name = "None",
                ability_desc = "A standard die.",
            })
            local max_order = 0
            for _, d in ipairs(player.dice_pool) do
                if (d._sort_order or 0) > max_order then max_order = d._sort_order or 0 end
            end
            new_die._sort_order = max_order + 1
            table.insert(player.dice_pool, new_die)
            local sort_mode = Settings.get("dice_sort_mode") or "default"
            player:sortDice(sort_mode)
            Toast.success("Added a new die to your pool!")
            Particles.sparkle(x, y, UI.colors.green_light, 20)
        end
        return nil
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

    for i, btn in pairs(self._hand_ref_buttons or {}) do
        if btn.hovered and btn.upgrade_idx then
            local ok, msg = shop:buyHandUpgrade(player, btn.upgrade_idx)
            if ok then
                Toast.success(msg)
                Particles.sparkle(x, y, UI.colors.accent, 12)
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

function ShopState:keypressed(key, player)
    if replacing_die then
        local count = player and #player.dice_pool or 0
        if key == "left" then
            if replace_focus > 0 then
                replace_focus = replace_focus - 1
                if replace_focus < 1 then replace_focus = count end
            else
                replace_focus = count
            end
        elseif key == "right" then
            if replace_focus > 0 then
                replace_focus = replace_focus + 1
                if replace_focus > count then replace_focus = 1 end
            else
                replace_focus = 1
            end
        elseif key == "down" then
            replace_focus = 0
        elseif key == "up" then
            if replace_focus == 0 then replace_focus = 1 end
        elseif key == "return" or key == "space" then
            if replace_focus == 0 then
                replacing_die = false
                selected_shop_die = nil
            elseif replace_focus >= 1 and replace_focus <= count then
                local ok, msg = shop:buyDie(player, selected_shop_die, replace_focus)
                if ok then
                    Toast.success(msg)
                else
                    Toast.error(msg)
                end
                replacing_die = false
                selected_shop_die = nil
            end
        elseif key == "escape" then
            replacing_die = false
            selected_shop_die = nil
        end
        return nil
    end

    if shop_mode == "grid" then
        local col_count = getColItemCount(shop_col)
        if key == "left" then
            shop_col = shop_col - 1
            if shop_col < 1 then shop_col = 3 end
            local new_count = getColItemCount(shop_col)
            shop_row = math.min(shop_row, new_count)
            if shop_row < 1 and new_count > 0 then shop_row = 1 end
        elseif key == "right" then
            shop_col = shop_col + 1
            if shop_col > 3 then shop_col = 1 end
            local new_count = getColItemCount(shop_col)
            shop_row = math.min(shop_row, new_count)
            if shop_row < 1 and new_count > 0 then shop_row = 1 end
        elseif key == "up" then
            if shop_row > 1 then
                shop_row = shop_row - 1
            else
                shop_mode = "ghost"
            end
        elseif key == "down" then
            if shop_row < col_count then
                shop_row = shop_row + 1
            else
                shop_mode = "continue"
            end
        elseif key == "return" or key == "space" then
            if shop_col == 1 and shop_row >= 1 and shop_row <= #shop.dice_inventory then
                replacing_die = true
                selected_shop_die = shop_row
                replace_focus = 1
            elseif shop_col == 2 and shop_row >= 1 and shop_row <= #shop.items_inventory then
                local ok, msg = shop:buyItem(player, shop_row)
                if ok then Toast.success(msg) else Toast.error(msg) end
            elseif shop_col == 3 and shop_row >= 1 and shop_row <= #shop_visible_hands then
                local hand = shop_visible_hands[shop_row]
                if hand then
                    for idx, upgrade in ipairs(shop.hand_upgrades) do
                        if upgrade.hand == hand then
                            local ok, msg = shop:buyHandUpgrade(player, idx)
                            if ok then Toast.success(msg) else Toast.error(msg) end
                            break
                        end
                    end
                end
            end
        elseif key == "tab" then
            shop_mode = "continue"
        end
    elseif shop_mode == "ghost" then
        if key == "down" then
            shop_mode = "grid"
            local col_count = getColItemCount(shop_col)
            if col_count > 0 then shop_row = 1 else shop_mode = "continue" end
        elseif key == "return" or key == "space" then
            if player and #player.dice_pool < MAX_DICE then
                local cost = getExtraDieCost(player)
                if player.currency >= cost then
                    player.currency = player.currency - cost
                    local Die = require("objects/die")
                    local new_die = Die:new({
                        name = "Vanilla Die", color = "black",
                        die_type = "vanilla", ability_name = "None",
                        ability_desc = "A standard die.",
                    })
                    local max_order = 0
                    for _, d in ipairs(player.dice_pool) do
                        if (d._sort_order or 0) > max_order then max_order = d._sort_order or 0 end
                    end
                    new_die._sort_order = max_order + 1
                    table.insert(player.dice_pool, new_die)
                    local sort_mode = Settings.get("dice_sort_mode") or "default"
                    player:sortDice(sort_mode)
                    Toast.success("Added a new die to your pool!")
                else
                    Toast.error("Not enough currency! ($" .. cost .. " needed)")
                end
            elseif player then
                Toast.error("Dice pool is full! (max " .. MAX_DICE .. ")")
            end
        elseif key == "tab" then
            shop_mode = "continue"
        end
    elseif shop_mode == "continue" then
        if key == "up" then
            shop_mode = "grid"
            local col_count = getColItemCount(shop_col)
            shop_row = math.max(1, col_count)
            if col_count == 0 then shop_mode = "ghost" end
        elseif key == "return" or key == "space" then
            return "next_round"
        elseif key == "tab" then
            local shift_held = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
            if shift_held then
                shop_mode = "grid"
                local col_count = getColItemCount(shop_col)
                shop_row = math.max(1, col_count)
                if col_count == 0 then shop_mode = "ghost" end
            end
        end
    end

    return nil
end

return ShopState
