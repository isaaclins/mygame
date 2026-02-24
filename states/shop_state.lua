local UI = require("functions/ui")
local Shop = require("objects/shop")
local Fonts = require("functions/fonts")
local Tween = require("functions/tween")
local Particles = require("functions/particles")
local Toast = require("functions/toast")
local Settings = require("functions/settings")
local CoinAnim = require("functions/coin_anim")

local ShopState = {}

local hand_examples = {
	["High Roll"] = { 6 },
	["Pair"] = { 3, 3 },
	["Two Pair"] = { 2, 2, 5, 5 },
	["X of a Kind"] = { 4, 4, 4 },
	["Small Straight"] = { 2, 3, 4, 5 },
	["Full House"] = { 3, 3, 3, 6, 6 },
	["Large Straight"] = { 1, 2, 3, 4, 5 },
	["All Even"] = { 2, 4, 6, 2, 4 },
	["All Odd"] = { 1, 3, 5, 1, 3 },
	["Three Pairs"] = { 1, 1, 3, 3, 5, 5 },
	["Two Triplets"] = { 2, 2, 2, 5, 5, 5 },
	["Full Run"] = { 1, 2, 3, 4, 5, 6 },
	["Pyramid"] = { 2, 4, 4, 4, 6, 6, 6, 6, 6 },
}

local shop = nil
local replacing_die = nil
local selected_shop_die = nil
local selected_shop_item = nil
local replace_mode = "die"

local section_anims = {}
local currency_anim = { display = 0 }
local card_hovers = {}

local shop_col = 1
local shop_row = 1
local shop_mode = "grid"
local replace_focus = 1
local shop_visible_hands = {}
local hovered_player_die = nil
local hovered_player_die_anchor_x = 0
local hovered_player_die_anchor_y = 0

local BULK_OPTIONS = { 1, 10, 100, -1 }
local BULK_LABELS = { [1] = "x1", [10] = "x10", [100] = "x100", [-1] = "MAX" }
local bulk_index = 1

local function getColItemCount(col)
	if not shop then
		return 0
	end
	if col == 1 then
		return #shop.dice_inventory
	elseif col == 2 then
		return #shop.items_inventory
	elseif col == 3 then
		return #shop_visible_hands
	end
	return 0
end

local function getExtraDieCost(player)
	return math.floor(((#player.dice_pool - 5 + 1) ^ 4) / 2)
end

local die_colors_map = {
	black = UI.colors.die_black,
	blue = UI.colors.die_blue,
	green = UI.colors.die_green,
	red = UI.colors.die_red,
}

function ShopState:init(player, all_dice_types, all_items)
	shop = Shop:new()
	shop:generate(player, all_dice_types, all_items)
	replacing_die = nil
	selected_shop_die = nil
	selected_shop_item = nil
	replace_mode = "die"
	card_hovers = {}
	shop_col = 1
	shop_row = 1
	shop_mode = "grid"
	replace_focus = 1
	bulk_index = 1
	hovered_player_die = nil
	hovered_player_die_anchor_x = 0
	hovered_player_die_anchor_y = 0

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
	if not replacing_die and hovered_player_die then
		self:drawDieModTooltip(hovered_player_die, hovered_player_die_anchor_x, hovered_player_die_anchor_y, W, H)
	end

	if not replacing_die then
		love.graphics.setFont(Fonts.get(11))
		UI.setColor(UI.colors.text_dark)
		local hints = "Arrows: Navigate  |  Enter: Select  |  Tab: Continue  |  Esc: Pause"
		if player.limit_break_count >= 1 then
			hints = hints .. "  |  B: Bulk (" .. BULK_LABELS[BULK_OPTIONS[bulk_index]] .. ")"
		end
		love.graphics.printf(hints, 0, H - 13, W, "center")
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

	currency_anim.display = currency_anim.display
		+ (player.currency - currency_anim.display) * math.min(1, 8 * love.timer.getDelta())
	UI.setColor(UI.colors.green)
	local hdr_font = love.graphics.getFont()
	local hdr_cs = hdr_font:getHeight() / CoinAnim.getHeight()
	CoinAnim.drawStaticWithAmount(
		UI.abbreviate(math.floor(currency_anim.display + 0.5)),
		0,
		22,
		"right",
		W - 24,
		hdr_cs
	)

	if not shop.free_choice_used then
		UI.drawBadge("FREE CHOICE AVAILABLE", 24, 22, UI.colors.free_badge, Fonts.get(14), true)
	end
end

function ShopState:drawPlayerDice(player, W, H)
	local count = #player.dice_pool
	local has_ghost = count < player.max_dice
	local slot_count = has_ghost and (count + 1) or count

	local min_die = 28
	local max_die = 60
	local gap = 8
	local label_h = 14
	local max_grid_w = W * 0.85

	local die_size = math.min(max_die, math.floor((max_grid_w - (slot_count - 1) * gap) / slot_count))
	local rows = 1
	if die_size < min_die then
		die_size = math.min(max_die, 40)
		local cols = math.floor((max_grid_w + gap) / (die_size + gap))
		cols = math.max(1, cols)
		rows = math.ceil(slot_count / cols)
	end
	local cols = math.ceil(slot_count / rows)
	local row_h = die_size + label_h + gap
	local grid_w = math.min(slot_count, cols) * die_size + (math.min(slot_count, cols) - 1) * gap
	local start_x = (W - grid_w) / 2
	local base_y = 80

	love.graphics.setFont(Fonts.get(12))
	UI.setColor(UI.colors.text_dim)
	love.graphics.printf("YOUR DICE", 0, 66, W, "center")

	local hovered_die = nil
	local hovered_dx, hovered_dy, hovered_size = 0, 0, 0
	local mx, my = love.mouse.getPosition()
	for i, die in ipairs(player.dice_pool) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local dx = start_x + col * (die_size + gap)
		local dy = base_y + row * row_h
		if UI.pointInRect(mx, my, dx, dy, die_size, die_size) then
			hovered_die = die
			hovered_dx, hovered_dy, hovered_size = dx, dy, die_size
		end
		local dot_color = die_colors_map[die.color] or UI.colors.die_black
		UI.drawDie(dx, dy, die_size, die.value, dot_color, nil, false, false, die.glow_color, false, die.items)
		love.graphics.setFont(Fonts.get(9))
		UI.setColor(UI.colors.text_dim)
		love.graphics.printf(die.name, dx - 5, dy + die_size + 2, die_size + 10, "center")
	end

	hovered_player_die = hovered_die
	if hovered_die then
		hovered_player_die_anchor_x = hovered_dx + hovered_size * 0.5
		hovered_player_die_anchor_y = hovered_dy
	else
		hovered_player_die_anchor_x = 0
		hovered_player_die_anchor_y = 0
	end

	self._dice_bar_height = base_y + rows * row_h

	if has_ghost then
		local ghost_col = count % cols
		local ghost_row = math.floor(count / cols)
		local gx = start_x + ghost_col * (die_size + gap)
		local gy = base_y + ghost_row * row_h
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
		local ghost_cs = Fonts.get(11):getHeight() / CoinAnim.getHeight()
		CoinAnim.drawStaticWithAmount(UI.abbreviate(cost), gx - 5, gy + die_size + 3, "center", die_size + 10, ghost_cs)

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
	local top = self._dice_bar_height or 160
	local section_y = top + sa.y_off
	local section_w = W / 3 - 30
	local section_h = H - top - 90

	shop_visible_hands = {}
	local upgrade_index_map = {}
	for i, upgrade in ipairs(shop.hand_upgrades) do
		table.insert(shop_visible_hands, upgrade.hand)
		upgrade_index_map[upgrade.hand] = i
	end

	local count = #shop_visible_hands
	local header_h = 36
	local card_gap = 6
	local avail_h = section_h - header_h - 8
	local card_h = math.max(50, math.min(72, math.floor((avail_h - (count - 1) * card_gap) / math.max(count, 1))))

	love.graphics.setColor(1, 1, 1, sa.alpha)
	UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

	love.graphics.setFont(Fonts.get(18))
	love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
	love.graphics.printf("HAND UPGRADES", section_x, section_y + 10, section_w, "center")

	local bulk_active = player.limit_break_count >= 1
	local cur_bulk = bulk_active and BULK_OPTIONS[bulk_index] or 1

	self._bulk_buttons = {}
	if bulk_active then
		local btn_w = 36
		local btn_h = 18
		local btn_gap = 4
		local total_btn_w = #BULK_OPTIONS * btn_w + (#BULK_OPTIONS - 1) * btn_gap
		local btn_start_x = section_x + (section_w - total_btn_w) / 2
		local btn_y = section_y + 30
		local mx_b, my_b = love.mouse.getPosition()
		for bi, bval in ipairs(BULK_OPTIONS) do
			local bx = btn_start_x + (bi - 1) * (btn_w + btn_gap)
			local selected = (bulk_index == bi)
			local bhovered = UI.pointInRect(mx_b, my_b, bx, btn_y, btn_w, btn_h)
			if selected then
				love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
			elseif bhovered then
				love.graphics.setColor(
					UI.colors.panel_hover[1],
					UI.colors.panel_hover[2],
					UI.colors.panel_hover[3],
					sa.alpha
				)
			else
				love.graphics.setColor(
					UI.colors.panel_light[1],
					UI.colors.panel_light[2],
					UI.colors.panel_light[3],
					sa.alpha * 0.6
				)
			end
			UI.roundRect("fill", bx, btn_y, btn_w, btn_h, 4)
			love.graphics.setFont(Fonts.get(11))
			if selected then
				love.graphics.setColor(0, 0, 0, sa.alpha)
			else
				love.graphics.setColor(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], sa.alpha * 0.8)
			end
			love.graphics.printf(BULK_LABELS[bval], bx, btn_y + 3, btn_w, "center")
			self._bulk_buttons[bi] = { x = bx, y = btn_y, w = btn_w, h = btn_h, hovered = bhovered }
		end
		header_h = header_h + 22
	end

	self._hand_ref_buttons = {}
	local mx, my = love.mouse.getPosition()

	for i, hand in ipairs(shop_visible_hands) do
		local card_x = section_x + 10
		local card_w = section_w - 20
		local card_y = section_y + header_h + (i - 1) * (card_h + card_gap)
		if card_y + card_h > section_y + section_h then
			break
		end

		local maxed = hand.upgrade_level >= hand.max_upgrade
		local upgrade_idx = upgrade_index_map[hand]
		local can_upgrade = upgrade_idx and not maxed

		local display_cost, bulk_count_actual
		if can_upgrade and shop.free_choice_used then
			if cur_bulk == -1 then
				bulk_count_actual, display_cost = shop:getBulkMaxCount(hand, player.currency)
				if bulk_count_actual == 0 then
					display_cost = hand:getUpgradeCost()
				end
			elseif cur_bulk > 1 then
				display_cost, bulk_count_actual = shop:getBulkUpgradeCost(hand, cur_bulk)
				if bulk_count_actual == 0 then
					display_cost = hand:getUpgradeCost()
				end
			else
				display_cost = hand:getUpgradeCost()
				bulk_count_actual = 1
			end
		else
			display_cost = hand:getUpgradeCost()
			bulk_count_actual = 1
		end

		local can_afford = can_upgrade and (not shop.free_choice_used or player.currency >= display_cost)
		local hovered = UI.pointInRect(mx, my, card_x, card_y, card_w, card_h)
		local is_focused = shop_mode == "grid" and shop_col == 3 and shop_row == i and not replacing_die

		local key = "hand_" .. i
		setCardHoverState(key, hovered or is_focused)
		local ch = getCardHover(key)

		if ch.shadow > 0.5 then
			love.graphics.setColor(0, 0, 0, 0.15 * sa.alpha)
			UI.roundRect("fill", card_x + 2, card_y + ch.shadow + 2, card_w, card_h, 6)
		end

		if can_afford then
			UI.setColor(hovered and UI.colors.panel_hover or UI.colors.panel_light)
		else
			local bg = UI.colors.panel_light
			love.graphics.setColor(bg[1], bg[2], bg[3], (bg[4] or 1) * (can_upgrade and 0.5 or 0.7))
		end
		UI.roundRect("fill", card_x, card_y + ch.lift, card_w, card_h, 6)

		if can_afford then
			love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], 0.08 * sa.alpha)
			UI.roundRect("fill", card_x, card_y + ch.lift, card_w, card_h, 6)
		end

		if is_focused then
			UI.drawFocusRect(card_x, card_y + ch.lift, card_w, card_h)
		end

		local text_x = card_x + 8
		local text_top = card_y + ch.lift + 6
		local dim = can_afford and 1.0 or (can_upgrade and 0.5 or 0.7)

		love.graphics.setFont(Fonts.get(14))
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
		love.graphics.print(name_text, text_x, text_top)

		if can_upgrade then
			love.graphics.setFont(Fonts.get(14))
			if not shop.free_choice_used then
				love.graphics.setColor(
					UI.colors.free_badge[1],
					UI.colors.free_badge[2],
					UI.colors.free_badge[3],
					sa.alpha
				)
				love.graphics.printf("FREE", card_x, text_top, card_w - 8, "right")
			else
				if can_afford then
					love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], sa.alpha)
				else
					love.graphics.setColor(UI.colors.red[1], UI.colors.red[2], UI.colors.red[3], sa.alpha)
				end
				local huc = Fonts.get(14):getHeight() / CoinAnim.getHeight()
				CoinAnim.drawStaticWithAmount(UI.abbreviate(display_cost), card_x, text_top, "right", card_w - 8, huc)
			end
		elseif maxed then
			love.graphics.setFont(Fonts.get(12))
			love.graphics.setColor(
				UI.colors.text_dark[1],
				UI.colors.text_dark[2],
				UI.colors.text_dark[3],
				sa.alpha * 0.6
			)
			love.graphics.printf("MAX", card_x, text_top + 2, card_w - 8, "right")
		end

		local stats_y = text_top + 18
		love.graphics.setFont(Fonts.get(11))
		love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], sa.alpha * 0.8)
		love.graphics.print(hand:getDisplayScore(), text_x, stats_y)

		local example = hand_examples[hand.name]
		if example and card_h >= 56 then
			local mini_die = math.min(18, math.floor((card_h - 40) * 0.9))
			local mini_gap = 3
			local dice_total_w = #example * mini_die + (#example - 1) * mini_gap
			local max_dice_w = card_w - 16
			if dice_total_w > max_dice_w then
				mini_die = math.floor((max_dice_w - (#example - 1) * mini_gap) / #example)
				dice_total_w = #example * mini_die + (#example - 1) * mini_gap
			end
			local dice_x = card_x + card_w - 8 - dice_total_w
			local dice_y = stats_y - 1
			for j, val in ipairs(example) do
				local ddx = dice_x + (j - 1) * (mini_die + mini_gap)
				love.graphics.setColor(1, 1, 1, sa.alpha * dim * 0.7)
				UI.drawDie(ddx, dice_y, mini_die, val, UI.colors.die_black)
			end
		end

		if can_upgrade and (hovered or is_focused) then
			love.graphics.setFont(Fonts.get(10))
			love.graphics.setColor(
				UI.colors.text_dark[1],
				UI.colors.text_dark[2],
				UI.colors.text_dark[3],
				sa.alpha * 0.5
			)
			local hint_y = card_y + ch.lift + card_h - 13
			love.graphics.printf("click to upgrade", card_x, hint_y, card_w - 8, "right")
		end

		self._hand_ref_buttons[i] = {
			x = card_x,
			y = card_y,
			w = card_w,
			h = card_h,
			hovered = hovered,
			upgrade_idx = upgrade_idx,
			can_upgrade = can_upgrade,
		}
	end

	if count == 0 then
		love.graphics.setFont(Fonts.get(12))
		UI.setColor(UI.colors.text_dark)
		love.graphics.printf("No upgrades available", section_x, section_y + 60, section_w, "center")
	end
end

function ShopState:drawDiceSection(player, W, H)
	local sa = section_anims[1] or { y_off = 0, alpha = 1 }
	local section_x = 20
	local top = self._dice_bar_height or 160
	local section_y = top + sa.y_off
	local section_w = W / 3 - 30
	local section_h = H - top - 90

	love.graphics.setColor(1, 1, 1, sa.alpha)
	UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

	love.graphics.setFont(Fonts.get(18))
	love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
	love.graphics.printf("DICE", section_x, section_y + 10, section_w, "center")

	-- Keep the dice shop continuously filled to the visible capacity of this panel.
	local card_step = 80
	local first_card_y = section_y + 40
	local card_h = 72
	local visible_slots = math.max(1, math.floor((section_y + section_h - first_card_y - card_h) / card_step) + 1)
	shop:ensureDiceOffers(visible_slots)

	self._dice_buttons = {}
	local mx, my = love.mouse.getPosition()

	for i, entry in ipairs(shop.dice_inventory) do
		local iy = section_y + 40 + (i - 1) * 80
		if iy + 72 > section_y + section_h then
			break
		end

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
		UI.drawDie(
			item_x + 8,
			iy + 8 + ch.lift,
			die_size,
			die.value,
			{ dot_color[1], dot_color[2], dot_color[3], dim },
			nil,
			false,
			false,
			die.glow_color,
			false,
			die.items
		)

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
			local dcs = Fonts.get(14):getHeight() / CoinAnim.getHeight()
			CoinAnim.drawStaticWithAmount(UI.abbreviate(entry.cost), item_x, iy + 8 + ch.lift, "right", item_w - 8, dcs)
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
	local top = self._dice_bar_height or 160
	local section_y = top + sa.y_off
	local section_w = W / 3 - 30
	local section_h = H - top - 90

	love.graphics.setColor(1, 1, 1, sa.alpha)
	UI.drawPanel(section_x, section_y, section_w, section_h, { border = UI.colors.panel_light })

	love.graphics.setFont(Fonts.get(18))
	love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], sa.alpha)
	love.graphics.printf("RELICS & DIE MODS", section_x, section_y + 10, section_w, "center")

	self._item_buttons = {}
	local mx, my = love.mouse.getPosition()

	for i, item in ipairs(shop.items_inventory) do
		local iy = section_y + 40 + (i - 1) * 68
		if iy + 60 > section_y + section_h then
			break
		end

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
		local badge_text = (item.target_scope == "dice") and "DIE MOD" or "RELIC"
		local badge_color = (item.target_scope == "dice") and UI.colors.item_scope_diemod or UI.colors.item_scope_relic
		local badge_font = Fonts.get(9)
		love.graphics.setFont(badge_font)
		love.graphics.setColor(badge_color[1], badge_color[2], badge_color[3], 0.9 * dim)
		love.graphics.printf(badge_text, item_x, iy + 8 + ch.lift, item_w - 90, "right")

		love.graphics.setFont(Fonts.get(11))
		love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], dim)
		love.graphics.printf(item.description, item_x + 8, iy + 26 + ch.lift, item_w - 16)

		UI.setColor(can_afford and UI.colors.accent or UI.colors.red)
		love.graphics.setFont(Fonts.get(14))
		local ics = Fonts.get(14):getHeight() / CoinAnim.getHeight()
		CoinAnim.drawStaticWithAmount(UI.abbreviate(item.cost), item_x, iy + 8 + ch.lift, "right", item_w - 8, ics)

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

	local owned_relics = player.items or {}
	local owned_mod_lines = {}
	for di, die in ipairs(player.dice_pool) do
		for _, item in ipairs(die.items or {}) do
			table.insert(owned_mod_lines, "D" .. di .. ": [" .. item.icon .. "] " .. item.name)
		end
	end
	if #owned_relics > 0 or #owned_mod_lines > 0 then
		love.graphics.setFont(Fonts.get(12))
		local owned_lines = 2 + #owned_relics + #owned_mod_lines
		local owned_y = section_y + section_h - 20 - owned_lines * 14
		UI.setColor(UI.colors.text_dim)
		love.graphics.print("Owned Relics:", section_x + 14, owned_y)
		for i, item in ipairs(owned_relics) do
			love.graphics.print("  [" .. item.icon .. "] " .. item.name, section_x + 14, owned_y + i * 14)
		end
		local mod_header_y = owned_y + (#owned_relics + 1) * 14
		love.graphics.setColor(
			UI.colors.item_scope_diemod[1],
			UI.colors.item_scope_diemod[2],
			UI.colors.item_scope_diemod[3],
			0.9
		)
		love.graphics.print("Die Mods:", section_x + 14, mod_header_y)
		love.graphics.setColor(UI.colors.text_dim)
		for i, label in ipairs(owned_mod_lines) do
			love.graphics.print("  " .. label, section_x + 14, mod_header_y + i * 14)
		end
	end
end

function ShopState:drawContinueButton(W, H)
	local btn_w, btn_h = 220, 52
	self._continue_hovered = UI.drawButton(
		"CONTINUE",
		(W - btn_w) / 2,
		H - 70,
		btn_w,
		btn_h,
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
	local max_panel_w = W * 0.85
	local die_size = 50
	local gap = 8
	local label_h = 14
	local cols = math.floor((max_panel_w - 60) / (die_size + gap))
	cols = math.min(cols, count)
	local rows = math.ceil(count / cols)
	local row_h = die_size + label_h + gap

	local grid_w = cols * die_size + (cols - 1) * gap
	local panel_w = math.max(400, grid_w + 60)
	local panel_h = 50 + rows * row_h + 50
	local px = (W - panel_w) / 2
	local py = math.max(20, (H - panel_h) / 2)

	UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent })

	love.graphics.setFont(Fonts.get(20))
	UI.setColor(UI.colors.text)
	local title = "Replace which die?"
	if replace_mode == "item" and selected_shop_item then
		local item = shop and shop.items_inventory[selected_shop_item]
		if item then
			title = "Apply " .. item.name .. " to which die?"
		else
			title = "Apply Die Mod to which die?"
		end
	end
	love.graphics.printf(title, px, py + 15, panel_w, "center")

	local grid_x = px + (panel_w - grid_w) / 2
	local grid_y = py + 50

	local mx, my = love.mouse.getPosition()
	self._replace_die_buttons = {}
	local hovered_die = nil
	local hovered_dx, hovered_dy = 0, 0

	for i, die in ipairs(player.dice_pool) do
		local col = (i - 1) % cols
		local row = math.floor((i - 1) / cols)
		local dx = grid_x + col * (die_size + gap)
		local dy = grid_y + row * row_h
		local hovered = UI.pointInRect(mx, my, dx, dy, die_size, die_size)
		if hovered then
			hovered_die = die
			hovered_dx, hovered_dy = dx, dy
		end
		local dot_color = die_colors_map[die.color] or UI.colors.die_black
		UI.drawDie(dx, dy, die_size, die.value, dot_color, nil, false, hovered, die.glow_color, false, die.items)
		self._replace_die_buttons[i] = { x = dx, y = dy, w = die_size, h = die_size }

		if replace_focus == i then
			UI.drawFocusRect(dx, dy, die_size, die_size)
		end

		love.graphics.setFont(Fonts.get(9))
		UI.setColor(UI.colors.text_dim)
		love.graphics.printf(die.name, dx - 5, dy + die_size + 2, die_size + 10, "center")
	end

	if hovered_die then
		self:drawDieModTooltip(hovered_die, hovered_dx + die_size * 0.5, hovered_dy, W, H)
	end

	local btn_y = py + panel_h - 40
	self._cancel_replace_hovered =
		UI.drawButton("CANCEL", px + panel_w / 2 - 60, btn_y, 120, 32, { font = Fonts.get(16), color = UI.colors.red })
	if replace_focus == 0 then
		UI.drawFocusRect(px + panel_w / 2 - 60, btn_y, 120, 32)
	end
end

function ShopState:drawDieModTooltip(die, anchor_x, anchor_y, W, H)
	local mods = die.items or {}
	if #mods == 0 then
		return
	end

	local pad = 10
	local tip_w = 220
	local tip_h = pad + 20 + 16 + #mods * 13 + pad
	local tip_x = math.max(8, math.min(anchor_x - tip_w / 2, W - tip_w - 8))
	local tip_y = anchor_y - tip_h - 10
	if tip_y < 65 then
		tip_y = anchor_y + 56
	end
	tip_y = math.max(55, math.min(tip_y, H - tip_h - 8))

	love.graphics.setColor(0.08, 0.08, 0.16, 0.95)
	UI.roundRect("fill", tip_x, tip_y, tip_w, tip_h, 8)
	love.graphics.setLineWidth(1.5)
	love.graphics.setColor(UI.colors.item_scope_diemod[1], UI.colors.item_scope_diemod[2], UI.colors.item_scope_diemod[3], 0.9)
	UI.roundRect("line", tip_x, tip_y, tip_w, tip_h, 8)
	love.graphics.setLineWidth(1)

	local y = tip_y + pad
	love.graphics.setFont(Fonts.get(14))
	UI.setColor(UI.colors.item_scope_diemod)
	love.graphics.printf(die.name, tip_x + pad, y, tip_w - pad * 2, "center")
	y = y + 20

	love.graphics.setFont(Fonts.get(11))
	love.graphics.setColor(UI.colors.item_scope_diemod[1], UI.colors.item_scope_diemod[2], UI.colors.item_scope_diemod[3], 0.85)
	love.graphics.printf("Die Mods", tip_x + pad, y, tip_w - pad * 2, "left")
	y = y + 16

	UI.setColor(UI.colors.text_dim)
	for _, item in ipairs(mods) do
		love.graphics.printf("[" .. item.icon .. "] " .. item.name, tip_x + pad, y, tip_w - pad * 2, "left")
		y = y + 13
	end
end

function ShopState:mousepressed(x, y, button, player)
	if button ~= 1 then
		return nil
	end

	if replacing_die then
		for i, btn in pairs(self._replace_die_buttons or {}) do
			if UI.pointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
				local ok, msg
				if replace_mode == "item" and selected_shop_item then
					ok, msg = shop:buyItem(player, selected_shop_item, i)
				else
					ok, msg = shop:buyDie(player, selected_shop_die, i)
				end
				if ok then
					Toast.success(msg)
					Particles.sparkle(x, y, UI.colors.green_light, 15)
				else
					Toast.error(msg)
				end
				replacing_die = false
				selected_shop_die = nil
				selected_shop_item = nil
				replace_mode = "die"
				return nil
			end
		end
		if self._cancel_replace_hovered then
			replacing_die = false
			selected_shop_die = nil
			selected_shop_item = nil
			replace_mode = "die"
			return nil
		end
		return nil
	end

	if self._ghost_die and self._ghost_die.hovered then
		local cost = self._ghost_die.cost
		if #player.dice_pool >= player.max_dice then
			Toast.error("Dice pool is full! (max " .. player.max_dice .. ")")
		elseif player.currency < cost then
			Toast.error("Not enough currency! ")
		else
			player.currency = player.currency - cost
			local Die = require("objects/die")
			local new_die = Die:new({
				name = "Vanilla Die",
				color = "black",
				die_type = "vanilla",
				ability_name = "None",
				ability_desc = "A standard die.",
				max_upgrade = 3 + 2 * player.limit_break_count,
			})
			local max_order = 0
			for _, d in ipairs(player.dice_pool) do
				if (d._sort_order or 0) > max_order then
					max_order = d._sort_order or 0
				end
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
			local entry = shop.dice_inventory[i]
			if shop.free_choice_used and player.currency < entry.cost then
				Toast.error("Not enough currency!)")
				return nil
			end
			replacing_die = true
			selected_shop_die = i
			selected_shop_item = nil
			replace_mode = "die"
			replace_focus = 1
			return nil
		end
	end

	for i, btn in pairs(self._item_buttons or {}) do
		if btn.hovered then
			local item = shop.items_inventory[i]
			if item and item.target_scope == "dice" then
				if player.currency < item.cost then
					Toast.error("Not enough currency")
					return nil
				end
				replacing_die = true
				selected_shop_item = i
				selected_shop_die = nil
				replace_mode = "item"
				replace_focus = 1
			else
				local ok, msg = shop:buyItem(player, i)
				if ok then
					Toast.success(msg)
					Particles.sparkle(x, y, UI.colors.green_light, 15)
				else
					Toast.error(msg)
				end
			end
			return nil
		end
	end

	for bi, btn in pairs(self._bulk_buttons or {}) do
		if btn.hovered then
			bulk_index = bi
			return nil
		end
	end

	local cur_bulk = (player.limit_break_count >= 1) and BULK_OPTIONS[bulk_index] or 1

	for i, btn in pairs(self._hand_ref_buttons or {}) do
		if btn.hovered and btn.upgrade_idx then
			local ok, msg = shop:buyHandUpgrade(player, btn.upgrade_idx, cur_bulk)
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
		local max_pw = love.graphics.getWidth() * 0.85
		local r_cols = math.floor((max_pw - 60) / (50 + 8))
		r_cols = math.min(r_cols, count)
		if r_cols < 1 then
			r_cols = 1
		end

		if key == "left" then
			if replace_focus > 0 then
				replace_focus = replace_focus - 1
				if replace_focus < 1 then
					replace_focus = count
				end
			else
				replace_focus = count
			end
		elseif key == "right" then
			if replace_focus > 0 then
				replace_focus = replace_focus + 1
				if replace_focus > count then
					replace_focus = 1
				end
			else
				replace_focus = 1
			end
		elseif key == "down" then
			if replace_focus == 0 then
				replace_focus = 1
			elseif replace_focus + r_cols <= count then
				replace_focus = replace_focus + r_cols
			else
				replace_focus = 0
			end
		elseif key == "up" then
			if replace_focus == 0 then
				replace_focus = count
			elseif replace_focus - r_cols >= 1 then
				replace_focus = replace_focus - r_cols
			else
				replace_focus = 0
			end
		elseif key == "return" or key == "space" then
			if replace_focus == 0 then
				replacing_die = false
				selected_shop_die = nil
				selected_shop_item = nil
				replace_mode = "die"
			elseif replace_focus >= 1 and replace_focus <= count then
				local ok, msg
				if replace_mode == "item" and selected_shop_item then
					ok, msg = shop:buyItem(player, selected_shop_item, replace_focus)
				else
					ok, msg = shop:buyDie(player, selected_shop_die, replace_focus)
				end
				if ok then
					Toast.success(msg)
				else
					Toast.error(msg)
				end
				replacing_die = false
				selected_shop_die = nil
				selected_shop_item = nil
				replace_mode = "die"
			end
		elseif key == "escape" then
			replacing_die = false
			selected_shop_die = nil
			selected_shop_item = nil
			replace_mode = "die"
		end
		return nil
	end

	if shop_mode == "grid" then
		local col_count = getColItemCount(shop_col)
		if key == "left" then
			shop_col = shop_col - 1
			if shop_col < 1 then
				shop_col = 3
			end
			local new_count = getColItemCount(shop_col)
			shop_row = math.min(shop_row, new_count)
			if shop_row < 1 and new_count > 0 then
				shop_row = 1
			end
		elseif key == "right" then
			shop_col = shop_col + 1
			if shop_col > 3 then
				shop_col = 1
			end
			local new_count = getColItemCount(shop_col)
			shop_row = math.min(shop_row, new_count)
			if shop_row < 1 and new_count > 0 then
				shop_row = 1
			end
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
				local entry = shop.dice_inventory[shop_row]
				if shop.free_choice_used and player.currency < entry.cost then
					Toast.error("Not enough currency!)")
				else
					replacing_die = true
					selected_shop_die = shop_row
					selected_shop_item = nil
					replace_mode = "die"
					replace_focus = 1
				end
			elseif shop_col == 2 and shop_row >= 1 and shop_row <= #shop.items_inventory then
				local item = shop.items_inventory[shop_row]
				if item and item.target_scope == "dice" then
					if player.currency < item.cost then
						Toast.error("Not enough currency")
					else
						replacing_die = true
						selected_shop_item = shop_row
						selected_shop_die = nil
						replace_mode = "item"
						replace_focus = 1
					end
				else
					local ok, msg = shop:buyItem(player, shop_row)
					if ok then
						Toast.success(msg)
					else
						Toast.error(msg)
					end
				end
			elseif shop_col == 3 and shop_row >= 1 and shop_row <= #shop_visible_hands then
				local kb_bulk = (player.limit_break_count >= 1) and BULK_OPTIONS[bulk_index] or 1
				local hand = shop_visible_hands[shop_row]
				if hand then
					for idx, upgrade in ipairs(shop.hand_upgrades) do
						if upgrade.hand == hand then
							local ok, msg = shop:buyHandUpgrade(player, idx, kb_bulk)
							if ok then
								Toast.success(msg)
							else
								Toast.error(msg)
							end
							break
						end
					end
				end
			end
		elseif key == "b" then
			if player.limit_break_count >= 1 then
				bulk_index = bulk_index % #BULK_OPTIONS + 1
			end
		elseif key == "tab" then
			shop_mode = "continue"
		end
	elseif shop_mode == "ghost" then
		if key == "down" then
			shop_mode = "grid"
			local col_count = getColItemCount(shop_col)
			if col_count > 0 then
				shop_row = 1
			else
				shop_mode = "continue"
			end
		elseif key == "return" or key == "space" then
			if player and #player.dice_pool < player.max_dice then
				local cost = getExtraDieCost(player)
				if player.currency >= cost then
					player.currency = player.currency - cost
					local Die = require("objects/die")
					local new_die = Die:new({
						name = "Vanilla Die",
						color = "black",
						die_type = "vanilla",
						ability_name = "None",
						ability_desc = "A standard die.",
						max_upgrade = 3 + 2 * player.limit_break_count,
					})
					local max_order = 0
					for _, d in ipairs(player.dice_pool) do
						if (d._sort_order or 0) > max_order then
							max_order = d._sort_order or 0
						end
					end
					new_die._sort_order = max_order + 1
					table.insert(player.dice_pool, new_die)
					local sort_mode = Settings.get("dice_sort_mode") or "default"
					player:sortDice(sort_mode)
					Toast.success("Added a new die to your pool!")
				else
					Toast.error("Not enough currency!")
				end
			elseif player then
				Toast.error("Dice pool is full! (max " .. player.max_dice .. ")")
			end
		elseif key == "tab" then
			shop_mode = "continue"
		end
	elseif shop_mode == "continue" then
		if key == "up" then
			shop_mode = "grid"
			local col_count = getColItemCount(shop_col)
			shop_row = math.max(1, col_count)
			if col_count == 0 then
				shop_mode = "ghost"
			end
		elseif key == "return" or key == "space" then
			return "next_round"
		elseif key == "tab" then
			local shift_held = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
			if shift_held then
				shop_mode = "grid"
				local col_count = getColItemCount(shop_col)
				shop_row = math.max(1, col_count)
				if col_count == 0 then
					shop_mode = "ghost"
				end
			end
		end
	end

	return nil
end

return ShopState
