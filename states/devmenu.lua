local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local Tween = require("functions/tween")
local Toast = require("functions/toast")
local Die = require("objects/die")
local Player = require("objects/player")
local createHands = require("content/hands")
local createDiceTypes = require("content/dice_types")
local createItems = require("content/items")
local createStickers = require("content/stickers")
local createBosses = require("content/bosses")

local DevMenu = {}

local current_tab = "player"
local tabs = { "player", "items", "dice", "stickers", "combos", "bosses", "hands" }
local tab_labels = {
	player = "Player",
	items = "Items",
	dice = "Dice",
	stickers = "Stickers",
	combos = "Combos",
	bosses = "Bosses",
	hands = "Hands",
}
local panel_anim = { scale = 0.8, alpha = 0 }
local anim_init = false

local draft = nil
local selected_boss = nil
local all_items_ref = nil
local all_dice_ref = nil
local all_stickers_ref = nil
local all_bosses_ref = nil
local selected_sticker_die = 1
local combo_catalog = nil
local combo_filtered_indices = {}
local combo_page = 1
local combo_page_size = 8
local combo_search_query = ""

local _btn_regions = {}
local active_input = nil
local input_buffer = ""
local input_cursor_blink = 0

local function initAnims()
	panel_anim = { scale = 0.85, alpha = 0 }
	Tween.to(panel_anim, 0.25, { scale = 1.0, alpha = 1 }, "outBack")
	anim_init = true
	_btn_regions = {}
end

local function createDraft()
	local p = Player:new()
	p.hands = createHands()
	p.currency = 50
	p.round = 1
	for i = 1, 5 do
		local die = Die:new({
			name = "Normal Die",
			color = "black",
			die_type = "Normal",
			ability_name = "None",
			ability_desc = "A standard die.",
		})
		die._sort_order = i
		table.insert(p.dice_pool, die)
	end
	return p
end

function DevMenu:open()
	anim_init = false
	current_tab = "player"
	all_items_ref = createItems()
	all_dice_ref = createDiceTypes()
	all_stickers_ref = createStickers()
	all_bosses_ref = createBosses()
	draft = createDraft()
	selected_boss = nil
	selected_sticker_die = 1
	combo_catalog = nil
	combo_filtered_indices = {}
	combo_page = 1
	combo_search_query = ""
	_btn_regions = {}
	active_input = nil
	input_buffer = ""
end

function DevMenu:getDraft()
	return draft
end

function DevMenu:getSelectedBoss()
	return selected_boss
end

local function registerBtn(id, x, y, w, h)
	_btn_regions[id] = { x = x, y = y, w = w, h = h }
end

local function smallBtn(text, x, y, w, h, color, hover_color)
	local font = Fonts.get(13)
	local mx, my = love.mouse.getPosition()
	local hovered = UI.pointInRect(mx, my, x, y, w, h)

	if hovered then
		UI.setColor(hover_color or UI.colors.panel_hover)
	else
		UI.setColor(color or UI.colors.panel_light)
	end
	UI.roundRect("fill", x, y, w, h, 4)

	UI.setColor(UI.colors.text)
	love.graphics.setFont(font)
	love.graphics.printf(text, x, y + (h - font:getHeight()) / 2, w, "center")
	return hovered
end

local function normalizeDiceLabel(name)
	return (name or ""):gsub("Die", "Dice")
end

local function buildStickerSubsets(stickers, max_distinct)
	local result = { {} }
	max_distinct = max_distinct or 5
	local ids = {}
	for _, st in ipairs(stickers or {}) do
		table.insert(ids, st.id)
	end
	table.sort(ids)
	local function walk(start_idx, path)
		if #path >= max_distinct then
			return
		end
		for i = start_idx, #ids do
			path[#path + 1] = ids[i]
			local clone = {}
			for j = 1, #path do
				clone[j] = path[j]
			end
			result[#result + 1] = clone
			walk(i + 1, path)
			path[#path] = nil
		end
	end
	walk(1, {})
	return result
end

local function getStickerDefMap()
	local map = {}
	for _, st in ipairs(all_stickers_ref or {}) do
		map[st.id] = st
	end
	return map
end

local function getAllowedValuesForDieType(die_type)
	if die_type == "broken" then
		return { 1 }
	end
	if die_type == "light" then
		return { 1, 2, 3 }
	end
	if die_type == "heavy" then
		return { 4, 5, 6 }
	end
	return { 1, 2, 3, 4, 5, 6 }
end

local function isValidStickerSetForDie(entry_ids, die_template)
	if not entry_ids or #entry_ids == 0 then
		return true
	end
	local st_map = getStickerDefMap()
	local probe = nil
	if die_template.die_type == "broken" then
		probe = Die:new({
			name = "Broken Dice",
			color = "black",
			die_type = "broken",
			ability_name = "Broken",
			ability_desc = "This die has shattered. Only rolls 1s.",
			weights = { 1, 0, 0, 0, 0, 0 },
		})
	else
		for _, tpl in ipairs(all_dice_ref or {}) do
			if tpl.die_type == die_template.die_type then
				probe = tpl:clone()
				break
			end
		end
	end
	if not probe then
		return false
	end
	for _, sid in ipairs(entry_ids) do
		local st = st_map[sid]
		if not st then
			return false
		end
		local ok = probe:addSticker(st, 1)
		if not ok then
			return false
		end
	end
	return true
end

local function ensureComboCatalog()
	if combo_catalog then
		return
	end
	combo_catalog = {}
	local subset_ids = buildStickerSubsets(all_stickers_ref or {}, 5)
	local die_templates = {}
	for _, die in ipairs(all_dice_ref or {}) do
		table.insert(die_templates, { name = normalizeDiceLabel(die.name), die_type = die.die_type, color = die.color })
	end
	table.insert(die_templates, { name = "Broken Dice", die_type = "broken", color = "black" })

	local sticker_name_by_id = {}
	for _, st in ipairs(all_stickers_ref or {}) do
		sticker_name_by_id[st.id] = st.name
	end

	for _, tpl in ipairs(die_templates) do
		for _, value in ipairs(getAllowedValuesForDieType(tpl.die_type)) do
			for _, ids in ipairs(subset_ids) do
				if isValidStickerSetForDie(ids, tpl) then
					local id_join = (#ids > 0) and table.concat(ids, " ") or "none"
					local name_join_parts = {}
					for _, sid in ipairs(ids) do
						name_join_parts[#name_join_parts + 1] = (sticker_name_by_id[sid] or sid)
					end
					local name_join = (#name_join_parts > 0) and table.concat(name_join_parts, " ") or "none"
					local search_text = string.lower(
						string.format("%s %s value %d stickers %s %s", tpl.name, tostring(tpl.die_type), value, id_join, name_join)
					)
					combo_catalog[#combo_catalog + 1] = {
						die_name = tpl.name,
						die_type = tpl.die_type,
						color = tpl.color,
						value = value,
						sticker_ids = ids,
						search_text = search_text,
					}
				end
			end
		end
	end
end

local function refreshComboFilter()
	ensureComboCatalog()
	combo_filtered_indices = {}
	local q = string.lower(combo_search_query or "")
	local tokens = {}
	for token in q:gmatch("%S+") do
		tokens[#tokens + 1] = token
	end
	for i, entry in ipairs(combo_catalog or {}) do
		local ok = true
		for _, token in ipairs(tokens) do
			if not entry.search_text:find(token, 1, true) then
				ok = false
				break
			end
		end
		if ok then
			combo_filtered_indices[#combo_filtered_indices + 1] = i
		end
	end
	local max_page = math.max(1, math.ceil(#combo_filtered_indices / combo_page_size))
	if combo_page > max_page then
		combo_page = max_page
	end
end

local function buildPreviewStickers(ids)
	if not ids or #ids == 0 then
		return nil
	end
	local by_id = {}
	for _, st in ipairs(all_stickers_ref or {}) do
		by_id[st.id] = st
	end
	local out = {}
	for i, sid in ipairs(ids) do
		local def = by_id[sid]
		out[sid] = {
			id = sid,
			name = def and def.name or sid,
			stacks = 1,
			stackable = def and def.stackable or true,
			svg_path = def and def.svg_path or nil,
			angle = ((i * 23) % 40) - 20,
			offset_x = ((i % 3) - 1) * 0.08,
			offset_y = ((i % 2 == 0) and -1 or 1) * 0.06,
			scale = 0.20,
		}
	end
	return out
end

local function formatStickerSummary(ids, max_chars)
	if not ids or #ids == 0 then
		return "none"
	end
	max_chars = max_chars or 34
	local s = table.concat(ids, ", ")
	if #s <= max_chars then
		return s
	end
	local out = {}
	local used = 0
	for i, id in ipairs(ids) do
		local add_len = #id + (i > 1 and 2 or 0)
		if used + add_len > max_chars - 6 then
			out[#out + 1] = "…+" .. tostring(#ids - i + 1)
			break
		end
		out[#out + 1] = id
		used = used + add_len
	end
	return table.concat(out, ", ")
end

local function formatStickerNameSummary(ids, max_chars)
	if not ids or #ids == 0 then
		return "none"
	end
	max_chars = max_chars or 46
	local st_map = getStickerDefMap()
	local names = {}
	for _, sid in ipairs(ids) do
		names[#names + 1] = (st_map[sid] and st_map[sid].name) or sid
	end
	local s = table.concat(names, ", ")
	if #s <= max_chars then
		return s
	end
	local out = {}
	local used = 0
	for i, name in ipairs(names) do
		local add_len = #name + (i > 1 and 2 or 0)
		if used + add_len > max_chars - 6 then
			out[#out + 1] = "…+" .. tostring(#names - i + 1)
			break
		end
		out[#out + 1] = name
		used = used + add_len
	end
	return table.concat(out, ", ")
end

local function makeDieFromComboEntry(entry)
	local die = nil
	if entry.die_type == "broken" then
		die = Die:new({
			name = "Broken Dice",
			color = "black",
			die_type = "broken",
			ability_name = "Broken",
			ability_desc = "This die has shattered. Only rolls 1s.",
			weights = { 1, 0, 0, 0, 0, 0 },
		})
	else
		for _, tpl in ipairs(all_dice_ref or {}) do
			if tpl.die_type == entry.die_type then
				die = tpl:clone()
				break
			end
		end
	end
	if not die then
		return nil, "Die template not found"
	end
	local allowed = getAllowedValuesForDieType(die.die_type)
	local value_ok = false
	for _, v in ipairs(allowed) do
		if v == entry.value then
			value_ok = true
			break
		end
	end
	die.value = value_ok and entry.value or allowed[1]
	die.locked = false
	local by_id = {}
	for _, st in ipairs(all_stickers_ref or {}) do
		by_id[st.id] = st
	end
	for _, sid in ipairs(entry.sticker_ids or {}) do
		local st = by_id[sid]
		if st then
			local ok, err = die:addSticker(st, 1)
			if not ok then
				return nil, err or ("Cannot add " .. sid)
			end
		end
	end
	return die, nil
end

local function drawPlayerTab(px, py, pw, ph)
	local ly = py + 10
	local pad = 16
	local label_font = Fonts.get(14)
	local val_font = Fonts.get(18)
	local btn_w, btn_h = 48, 28

	local rows = {
		{ label = "Currency", key = "currency", steps = { -100, -10, 10, 100 } },
		{ label = "Rerolls", key = "rerolls_remaining", steps = { -1, 1 } },
		{ label = "Round", key = "round", steps = { -1, 1, 5 } },
		{ label = "Max Rerolls", key = "max_rerolls", steps = { -1, 1 } },
		{ label = "Base Rerolls", key = "base_rerolls", steps = { -1, 1 } },
		{ label = "Max Dice", key = "max_dice", steps = { -1, 1 } },
	}

	local val_box_w, val_box_h = 80, 28

	for _, row in ipairs(rows) do
		love.graphics.setFont(label_font)
		UI.setColor(UI.colors.text_dim)
		love.graphics.print(row.label, px + pad, ly + 5)

		local vx = px + 160
		local vy = ly + 2
		local is_editing = active_input == row.key

		if is_editing then
			love.graphics.setColor(0.15, 0.15, 0.25, 1)
			UI.roundRect("fill", vx, vy, val_box_w, val_box_h, 4)
			love.graphics.setColor(UI.colors.orange[1], UI.colors.orange[2], UI.colors.orange[3], 0.8)
			love.graphics.setLineWidth(2)
			UI.roundRect("line", vx, vy, val_box_w, val_box_h, 4)
			love.graphics.setLineWidth(1)

			love.graphics.setFont(val_font)
			UI.setColor(UI.colors.text)
			love.graphics.printf(
				input_buffer,
				vx + 4,
				vy + (val_box_h - val_font:getHeight()) / 2,
				val_box_w - 8,
				"center"
			)

			input_cursor_blink = input_cursor_blink + love.timer.getDelta()
			if math.floor(input_cursor_blink * 2) % 2 == 0 then
				local text_w = val_font:getWidth(input_buffer)
				local cx = vx + (val_box_w + text_w) / 2 + 2
				UI.setColor(UI.colors.text)
				love.graphics.setLineWidth(2)
				love.graphics.line(cx, vy + 5, cx, vy + val_box_h - 5)
				love.graphics.setLineWidth(1)
			end
		else
			local mx, my = love.mouse.getPosition()
			local hovered = UI.pointInRect(mx, my, vx, vy, val_box_w, val_box_h)

			if hovered then
				love.graphics.setColor(0.12, 0.12, 0.22, 1)
				UI.roundRect("fill", vx, vy, val_box_w, val_box_h, 4)
				love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.4)
				love.graphics.setLineWidth(1)
				UI.roundRect("line", vx, vy, val_box_w, val_box_h, 4)
			end

			love.graphics.setFont(val_font)
			UI.setColor(UI.colors.accent)
			local val = draft[row.key] or 0
			love.graphics.printf(tostring(val), vx, vy + (val_box_h - val_font:getHeight()) / 2, val_box_w, "center")
		end

		registerBtn("player_val_" .. row.key, vx, vy, val_box_w, val_box_h)

		local bx = px + 260
		for _, step in ipairs(row.steps) do
			local label = (step > 0 and "+" or "") .. tostring(step)
			local color = step > 0 and UI.colors.green or UI.colors.red
			local hover = step > 0 and UI.colors.green_light or { 0.95, 0.30, 0.30, 1 }
			smallBtn(label, bx, ly + 2, btn_w, btn_h, color, hover)
			registerBtn("player_" .. row.key .. "_" .. tostring(step), bx, ly + 2, btn_w, btn_h)
			bx = bx + btn_w + 6
		end

		ly = ly + 40
	end

	ly = ly + 10
	love.graphics.setFont(label_font)
	UI.setColor(UI.colors.text_dim)
	love.graphics.print("Target Score: " .. draft:getTargetScore(), px + pad, ly)
	ly = ly + 24
	love.graphics.print("Boss Round: " .. (draft:isBossRound() and "Yes" or "No"), px + pad, ly)
end

local function drawItemsTab(px, py, pw, ph)
	local ly = py + 10
	local pad = 16
	local row_h = 52
	local name_font = Fonts.get(15)
	local desc_font = Fonts.get(12)
	local btn_w, btn_h = 70, 28

	for idx, item in ipairs(all_items_ref) do
		local owned = false
		for _, pi in ipairs(draft.items) do
			if pi.name == item.name then
				owned = true
				break
			end
		end

		if owned then
			love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], 0.08)
			UI.roundRect("fill", px + 8, ly, pw - 16, row_h - 4, 6)
		end

		love.graphics.setFont(name_font)
		UI.setColor(UI.colors.text)
		love.graphics.print(item.icon .. "  " .. item.name, px + pad, ly + 4)

		love.graphics.setFont(desc_font)
		UI.setColor(UI.colors.text_dim)
		love.graphics.print(item.description, px + pad, ly + 24)

		love.graphics.setFont(desc_font)
		UI.setColor(UI.colors.accent_dim)
		love.graphics.printf("$" .. item.cost, px + pw - 160 - btn_w, ly + 8, 50, "right")

		local btn_label = owned and "Remove" or "Add"
		local btn_color = owned and UI.colors.red or UI.colors.green
		local btn_hover = owned and { 0.95, 0.30, 0.30, 1 } or UI.colors.green_light
		smallBtn(btn_label, px + pw - btn_w - pad, ly + 10, btn_w, btn_h, btn_color, btn_hover)
		registerBtn("item_" .. idx, px + pw - btn_w - pad, ly + 10, btn_w, btn_h)

		ly = ly + row_h
	end
end

local function drawDiceTab(px, py, pw, ph)
	local ly = py + 10
	local pad = 16
	local small_font = Fonts.get(12)
	local die_size = 36
	local btn_w, btn_h = 28, 28

	love.graphics.setFont(Fonts.get(13))
	UI.setColor(UI.colors.text_dim)
	love.graphics.print("Starting Dice (" .. #draft.dice_pool .. ")", px + pad, ly)
	ly = ly + 20

	local dice_per_row = math.floor((pw - pad * 2) / (die_size + btn_w + 12))
	local col = 0
	for i, die in ipairs(draft.dice_pool) do
		local dx = px + pad + col * (die_size + btn_w + 16)
		local dot_color = UI.colors.die_black
		if die.color == "blue" then
			dot_color = UI.colors.die_blue
		elseif die.color == "green" then
			dot_color = UI.colors.die_green
		elseif die.color == "red" then
			dot_color = UI.colors.die_red
		end

		UI.drawDie(dx, ly, die_size, die.value, dot_color, nil, false, false, die.glow_color, false, die.items, nil, nil, nil, die.stickers)

		love.graphics.setFont(small_font)
		UI.setColor(UI.colors.text_dim)
		love.graphics.print(normalizeDiceLabel(die.name):sub(1, 10), dx, ly + die_size + 2)

		smallBtn("X", dx + die_size + 4, ly + 4, btn_w, btn_h, UI.colors.red, { 0.95, 0.30, 0.30, 1 })
		registerBtn("dice_remove_" .. i, dx + die_size + 4, ly + 4, btn_w, btn_h)

		col = col + 1
		if col >= dice_per_row then
			col = 0
			ly = ly + die_size + 22
		end
	end
	if col > 0 then
		ly = ly + die_size + 22
	end

	ly = ly + 10
	love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], 0.5)
	love.graphics.line(px + pad, ly, px + pw - pad, ly)
	ly = ly + 10

	love.graphics.setFont(Fonts.get(13))
	UI.setColor(UI.colors.text_dim)
	love.graphics.print("Add Dice", px + pad, ly)
	ly = ly + 20

	local add_btn_w = 100
	local add_btn_h = 32
	local cols = math.floor((pw - pad * 2 + 8) / (add_btn_w + 8))
	col = 0
	for idx, die in ipairs(all_dice_ref) do
		local bx = px + pad + col * (add_btn_w + 8)
		smallBtn(normalizeDiceLabel(die.name):sub(1, 12), bx, ly, add_btn_w, add_btn_h, UI.colors.blue, UI.colors.blue_hover)
		registerBtn("dice_add_" .. idx, bx, ly, add_btn_w, add_btn_h)
		col = col + 1
		if col >= cols then
			col = 0
			ly = ly + add_btn_h + 6
		end
	end

	local broken_bx = px + pad + col * (add_btn_w + 8)
	smallBtn("Broken Dice", broken_bx, ly, add_btn_w, add_btn_h, UI.colors.red, { 0.95, 0.30, 0.30, 1 })
	registerBtn("dice_add_broken", broken_bx, ly, add_btn_w, add_btn_h)

	local browse_y = ly + add_btn_h + 12
	smallBtn("Open Combo Browser", px + pad, browse_y, 180, 30, UI.colors.purple, UI.colors.purple_dim)
	registerBtn("dice_open_combos", px + pad, browse_y, 180, 30)
end

local function drawBossesTab(px, py, pw, ph)
	local ly = py + 10
	local pad = 16
	local row_h = 56
	local name_font = Fonts.get(16)
	local desc_font = Fonts.get(12)
	local btn_w, btn_h = 70, 28

	smallBtn("No Boss", px + pw - 100 - pad, ly, 100, btn_h, UI.colors.red, { 0.95, 0.30, 0.30, 1 })
	registerBtn("boss_clear", px + pw - 100 - pad, ly, 100, btn_h)

	love.graphics.setFont(Fonts.get(13))
	UI.setColor(UI.colors.text_dim)
	local active_name = selected_boss and selected_boss.name or "None"
	love.graphics.print("Forced Boss: " .. active_name, px + pad, ly + 5)
	ly = ly + 40

	for idx, boss in ipairs(all_bosses_ref) do
		local is_active = selected_boss and selected_boss.name == boss.name

		if is_active then
			love.graphics.setColor(UI.colors.purple[1], UI.colors.purple[2], UI.colors.purple[3], 0.10)
			UI.roundRect("fill", px + 8, ly, pw - 16, row_h - 4, 6)
		end

		love.graphics.setFont(name_font)
		UI.setColor(is_active and UI.colors.purple or UI.colors.text)
		love.graphics.print(boss.icon .. "  " .. boss.name, px + pad, ly + 4)

		love.graphics.setFont(desc_font)
		UI.setColor(UI.colors.text_dim)
		love.graphics.print(boss.description, px + pad, ly + 26)

		local lbl = is_active and "Active" or "Select"
		local col = is_active and UI.colors.green or UI.colors.purple
		local hcol = is_active and UI.colors.green_light or UI.colors.purple_dim
		smallBtn(lbl, px + pw - btn_w - pad, ly + 12, btn_w, btn_h, col, hcol)
		registerBtn("boss_force_" .. idx, px + pw - btn_w - pad, ly + 12, btn_w, btn_h)

		ly = ly + row_h
	end
end

local function drawHandsTab(px, py, pw, ph)
	local ly = py + 8
	local pad = 16
	local row_h = 30
	local name_font = Fonts.get(13)
	local val_font = Fonts.get(13)
	local btn_w, btn_h = 28, 24
	local col_w = math.floor((pw - pad * 2) / 2)
	local lvl_box_w, lvl_box_h = 56, 22

	for idx, hand in ipairs(draft.hands) do
		local col = (idx - 1) % 2
		local row = math.floor((idx - 1) / 2)
		local hx = px + pad + col * col_w
		local hy = ly + row * row_h

		love.graphics.setFont(name_font)
		UI.setColor(UI.colors.text)
		love.graphics.print(hand.name, hx, hy + 3)

		local lvl_x = hx + 130
		local lvl_y = hy + 2
		local input_key = "hand_lvl_" .. idx
		local is_editing = active_input == input_key

		if is_editing then
			love.graphics.setColor(0.15, 0.15, 0.25, 1)
			UI.roundRect("fill", lvl_x, lvl_y, lvl_box_w, lvl_box_h, 3)
			love.graphics.setColor(UI.colors.orange[1], UI.colors.orange[2], UI.colors.orange[3], 0.8)
			love.graphics.setLineWidth(2)
			UI.roundRect("line", lvl_x, lvl_y, lvl_box_w, lvl_box_h, 3)
			love.graphics.setLineWidth(1)

			love.graphics.setFont(val_font)
			UI.setColor(UI.colors.text)
			love.graphics.printf(
				input_buffer,
				lvl_x + 2,
				lvl_y + (lvl_box_h - val_font:getHeight()) / 2,
				lvl_box_w - 4,
				"center"
			)

			input_cursor_blink = input_cursor_blink + love.timer.getDelta()
			if math.floor(input_cursor_blink * 2) % 2 == 0 then
				local text_w = val_font:getWidth(input_buffer)
				local cx = lvl_x + (lvl_box_w + text_w) / 2 + 1
				UI.setColor(UI.colors.text)
				love.graphics.setLineWidth(2)
				love.graphics.line(cx, lvl_y + 3, cx, lvl_y + lvl_box_h - 3)
				love.graphics.setLineWidth(1)
			end
		else
			local mx, my = love.mouse.getPosition()
			local hovered = UI.pointInRect(mx, my, lvl_x, lvl_y, lvl_box_w, lvl_box_h)

			if hovered then
				love.graphics.setColor(0.12, 0.12, 0.22, 1)
				UI.roundRect("fill", lvl_x, lvl_y, lvl_box_w, lvl_box_h, 3)
				love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.4)
				love.graphics.setLineWidth(1)
				UI.roundRect("line", lvl_x, lvl_y, lvl_box_w, lvl_box_h, 3)
			end

			love.graphics.setFont(val_font)
			UI.setColor(UI.colors.accent_dim)
			local lvl_text = "Lv" .. hand.upgrade_level .. "/" .. hand.max_upgrade
			love.graphics.printf(lvl_text, lvl_x, lvl_y + (lvl_box_h - val_font:getHeight()) / 2, lvl_box_w, "center")
		end

		registerBtn(input_key, lvl_x, lvl_y, lvl_box_w, lvl_box_h)

		smallBtn("-", hx + col_w - btn_w * 2 - 12, hy + 1, btn_w, btn_h, UI.colors.red, { 0.95, 0.30, 0.30, 1 })
		registerBtn("hand_down_" .. idx, hx + col_w - btn_w * 2 - 12, hy + 1, btn_w, btn_h)

		smallBtn("+", hx + col_w - btn_w - 6, hy + 1, btn_w, btn_h, UI.colors.green, UI.colors.green_light)
		registerBtn("hand_up_" .. idx, hx + col_w - btn_w - 6, hy + 1, btn_w, btn_h)
	end
end

local function setStickerStacks(die, sticker_def, target_stacks)
	target_stacks = math.max(0, math.floor(target_stacks or 0))
	local current = die:getStickerStacks(sticker_def.id)
	if current == target_stacks then
		return true, current
	end
	if target_stacks == 0 then
		if current > 0 then
			die:removeSticker(sticker_def.id, current)
		end
		return true, 0
	end
	if target_stacks > current then
		local ok, result = die:addSticker(sticker_def, target_stacks - current)
		if not ok then
			return false, result
		end
		return true, result
	end
	die:removeSticker(sticker_def.id, current - target_stacks)
	return true, target_stacks
end

local function drawStickersTab(px, py, pw, ph)
	local pad = 16
	local ly = py + 10
	local row_h = 44
	local btn_h = 26
	local btn_w = 42
	local value_w = 58

	if #draft.dice_pool == 0 then
		love.graphics.setFont(Fonts.get(14))
		UI.setColor(UI.colors.text_dim)
		love.graphics.print("No dice in draft.", px + pad, ly)
		return
	end

	if selected_sticker_die < 1 then
		selected_sticker_die = 1
	elseif selected_sticker_die > #draft.dice_pool then
		selected_sticker_die = #draft.dice_pool
	end

	local die = draft.dice_pool[selected_sticker_die]
	love.graphics.setFont(Fonts.get(14))
	UI.setColor(UI.colors.text_dim)
	love.graphics.print("Target Dice", px + pad, ly + 4)

	local picker_x = px + 108
	smallBtn("<", picker_x, ly, 28, btn_h, UI.colors.panel_light, UI.colors.panel_hover)
	registerBtn("sticker_die_prev", picker_x, ly, 28, btn_h)
	smallBtn(">", picker_x + 236, ly, 28, btn_h, UI.colors.panel_light, UI.colors.panel_hover)
	registerBtn("sticker_die_next", picker_x + 236, ly, 28, btn_h)

	love.graphics.setFont(Fonts.get(15))
	UI.setColor(UI.colors.accent)
	love.graphics.printf(
		"[" .. selected_sticker_die .. "] " .. normalizeDiceLabel(die.name),
		picker_x + 34,
		ly + 3,
		196,
		"center"
	)
	ly = ly + 36

	love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], 0.5)
	love.graphics.line(px + pad, ly, px + pw - pad, ly)
	ly = ly + 8

	for idx, sticker in ipairs(all_stickers_ref or {}) do
		local y = ly + (idx - 1) * row_h
		local cur = die:getStickerStacks(sticker.id)
		local editing_key = "sticker_set_" .. idx
		local editing = active_input == editing_key

		love.graphics.setFont(Fonts.get(14))
		UI.setColor(cur > 0 and UI.colors.text or UI.colors.text_dim)
		love.graphics.print(sticker.name, px + pad, y + 2)
		love.graphics.setFont(Fonts.get(11))
		UI.setColor(UI.colors.text_dark)
		love.graphics.print(sticker.stackable and ("max " .. tostring(sticker.stack_limit)) or "unstackable", px + pad, y + 20)

		local vx = px + pw - pad - (btn_w * 4 + value_w + 26)
		local vy = y + 8
		if editing then
			love.graphics.setColor(0.15, 0.15, 0.25, 1)
			UI.roundRect("fill", vx, vy, value_w, btn_h, 3)
			love.graphics.setColor(UI.colors.orange[1], UI.colors.orange[2], UI.colors.orange[3], 0.8)
			love.graphics.setLineWidth(2)
			UI.roundRect("line", vx, vy, value_w, btn_h, 3)
			love.graphics.setLineWidth(1)
			love.graphics.setFont(Fonts.get(13))
			UI.setColor(UI.colors.text)
			love.graphics.printf(input_buffer, vx + 2, vy + 4, value_w - 4, "center")
		else
			love.graphics.setColor(0.12, 0.12, 0.22, 1)
			UI.roundRect("fill", vx, vy, value_w, btn_h, 3)
			love.graphics.setFont(Fonts.get(13))
			UI.setColor(UI.colors.accent)
			love.graphics.printf(tostring(cur), vx, vy + 4, value_w, "center")
		end
		registerBtn(editing_key, vx, vy, value_w, btn_h)

		local bx = vx + value_w + 6
		smallBtn("-5", bx, vy, btn_w, btn_h, UI.colors.red, { 0.95, 0.30, 0.30, 1 })
		registerBtn("sticker_sub5_" .. idx, bx, vy, btn_w, btn_h)
		bx = bx + btn_w + 4
		smallBtn("-1", bx, vy, btn_w, btn_h, UI.colors.red, { 0.95, 0.30, 0.30, 1 })
		registerBtn("sticker_sub_" .. idx, bx, vy, btn_w, btn_h)
		bx = bx + btn_w + 4
		smallBtn("+1", bx, vy, btn_w, btn_h, UI.colors.green, UI.colors.green_light)
		registerBtn("sticker_add_" .. idx, bx, vy, btn_w, btn_h)
		bx = bx + btn_w + 4
		smallBtn("+5", bx, vy, btn_w, btn_h, UI.colors.green, UI.colors.green_light)
		registerBtn("sticker_add5_" .. idx, bx, vy, btn_w, btn_h)
	end
end

local function drawCombinationsTab(px, py, pw, ph)
	local pad = 16
	local ly = py + 8
	ensureComboCatalog()
	refreshComboFilter()

	love.graphics.setFont(Fonts.get(13))
	UI.setColor(UI.colors.text_dim)
	love.graphics.print("Search", px + pad, ly + 6)

	local search_x = px + pad + 60
	local search_y = ly + 2
	local search_w = 360
	local search_h = 28
	local editing = active_input == "combo_search"

	love.graphics.setColor(0.12, 0.12, 0.22, 1)
	UI.roundRect("fill", search_x, search_y, search_w, search_h, 4)
	if editing then
		love.graphics.setColor(UI.colors.orange[1], UI.colors.orange[2], UI.colors.orange[3], 0.9)
	else
		love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.35)
	end
	love.graphics.setLineWidth(editing and 2 or 1)
	UI.roundRect("line", search_x, search_y, search_w, search_h, 4)
	love.graphics.setLineWidth(1)

	love.graphics.setFont(Fonts.get(13))
	UI.setColor(UI.colors.text)
	local shown_query = editing and input_buffer or combo_search_query
	love.graphics.printf((shown_query ~= "" and shown_query or "die/sticker/value..."), search_x + 8, search_y + 6, search_w - 16, "left")
	registerBtn("combo_search_box", search_x, search_y, search_w, search_h)

	local total = #combo_catalog
	local shown = #combo_filtered_indices
	local max_page = math.max(1, math.ceil(shown / combo_page_size))
	local info = string.format("%d / %d matches", shown, total)
	UI.setColor(UI.colors.text_dim)
	local nav_right = px + pw - pad
	local next_x = nav_right - 30
	local prev_x = next_x - 36
	smallBtn("<", prev_x, ly + 2, 30, 28, UI.colors.panel_light, UI.colors.panel_hover)
	registerBtn("combo_prev_page", prev_x, ly + 2, 30, 28)
	smallBtn(">", next_x, ly + 2, 30, 28, UI.colors.panel_light, UI.colors.panel_hover)
	registerBtn("combo_next_page", next_x, ly + 2, 30, 28)
	UI.setColor(UI.colors.text_dim)
	love.graphics.printf("Page " .. combo_page .. "/" .. max_page, prev_x - 110, ly + 6, 100, "right")
	love.graphics.printf(info, search_x + search_w + 12, ly + 6, math.max(40, prev_x - (search_x + search_w + 20) - 120), "left")

	ly = ly + 40
	love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], 0.5)
	love.graphics.line(px + pad, ly, px + pw - pad, ly)
	ly = ly + 8

	local cols = 2
	local card_w = math.floor((pw - pad * 2 - 10) / cols)
	local card_h = 86
	local start_idx = (combo_page - 1) * combo_page_size + 1
	local end_idx = math.min(#combo_filtered_indices, start_idx + combo_page_size - 1)
	local slot = 0
	local mx, my = love.mouse.getPosition()
	local t = love.timer.getTime()
	local hovered_entry = nil
	local hovered_x, hovered_y, hovered_w = 0, 0, 0
	for i = start_idx, end_idx do
		local row = math.floor(slot / cols)
		local col = slot % cols
		local cx = px + pad + col * (card_w + 10)
		local cy = ly + row * (card_h + 8)
		local combo_idx = combo_filtered_indices[i]
		local entry = combo_catalog[combo_idx]
		local hovered = UI.pointInRect(mx, my, cx, cy, card_w, card_h)
		if hovered then
			hovered_entry = entry
			hovered_x, hovered_y, hovered_w = cx, cy, card_w
		end
		local dot_color = UI.colors.die_black
		if entry.color == "blue" then
			dot_color = UI.colors.die_blue
		elseif entry.color == "green" then
			dot_color = UI.colors.die_green
		elseif entry.color == "red" then
			dot_color = UI.colors.die_red
		end

		if hovered then
			love.graphics.setColor(UI.colors.panel_hover)
		else
			love.graphics.setColor(UI.colors.panel_light)
		end
		UI.roundRect("fill", cx, cy, card_w, card_h, 5)
		if hovered then
			love.graphics.setLineWidth(2)
			love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.8)
			UI.roundRect("line", cx, cy, card_w, card_h, 5)
			love.graphics.setLineWidth(1)
		end
		local die_size = hovered and 52 or 50
		local die_y_off = hovered and (-1 - 2 * math.sin(t * 4)) or 0
		UI.drawDie(
			cx + 8,
			cy + 8 + die_y_off,
			die_size,
			entry.value,
			dot_color,
			nil,
			false,
			hovered,
			hovered and UI.colors.accent or nil,
			false,
			nil,
			nil,
			nil,
			nil,
			buildPreviewStickers(entry.sticker_ids)
		)

		love.graphics.setFont(Fonts.get(12))
		UI.setColor(UI.colors.text)
		love.graphics.printf(entry.die_name .. "  v" .. tostring(entry.value), cx + 66, cy + 8, card_w - 72, "left")
		love.graphics.setFont(Fonts.get(11))
		UI.setColor(UI.colors.text_dim)
		local s_text = formatStickerNameSummary(entry.sticker_ids, 56)
		love.graphics.printf("Stickers: " .. s_text, cx + 66, cy + 30, card_w - 72, "left")
		love.graphics.printf("Type: " .. tostring(entry.die_type), cx + 66, cy + 46, card_w - 72, "left")
		UI.setColor(UI.colors.accent_dim)
		love.graphics.printf("Click to add exact setup", cx + 66, cy + 62, card_w - 72, "left")
		registerBtn("combo_pick_" .. tostring(combo_idx), cx, cy, card_w, card_h)
		slot = slot + 1
	end

	if hovered_entry then
		local tip_w = math.min(460, pw - 40)
		local tip_x = math.max(px + 12, math.min(hovered_x + hovered_w * 0.5 - tip_w * 0.5, px + pw - tip_w - 12))
		local tip_y = hovered_y + card_h + 6
		local line_h = 16
		local ids = hovered_entry.sticker_ids or {}
		local st_map = getStickerDefMap()
		local tip_h = 30 + math.max(1, #ids) * line_h + 10
		love.graphics.setColor(0.07, 0.07, 0.14, 0.97)
		UI.roundRect("fill", tip_x, tip_y, tip_w, tip_h, 6)
		love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.85)
		love.graphics.setLineWidth(1)
		UI.roundRect("line", tip_x, tip_y, tip_w, tip_h, 6)
		love.graphics.setLineWidth(1)
		love.graphics.setFont(Fonts.get(12))
		UI.setColor(UI.colors.text)
		love.graphics.print("Full stickers", tip_x + 10, tip_y + 8)
		love.graphics.setFont(Fonts.get(11))
		if #ids == 0 then
			UI.setColor(UI.colors.text_dim)
			love.graphics.print("- none", tip_x + 10, tip_y + 8 + line_h)
		else
			for i, sid in ipairs(ids) do
				local st = st_map[sid]
				local label = (st and st.name or sid) .. " (" .. sid .. ")"
				UI.setColor(UI.colors.text_dim)
				love.graphics.print("- " .. label, tip_x + 10, tip_y + 8 + i * line_h)
			end
		end
	end
end

function DevMenu:draw()
	if not anim_init then
		initAnims()
	end
	if not draft then
		return
	end

	local W, H = love.graphics.getDimensions()

	love.graphics.setColor(0, 0, 0, 0.65 * panel_anim.alpha)
	love.graphics.rectangle("fill", 0, 0, W, H)

	local panel_w = math.min(900, W - 40)
	local panel_h = math.min(580, H - 40)
	local px = (W - panel_w) / 2
	local py = (H - panel_h) / 2

	love.graphics.push()
	love.graphics.translate(px + panel_w / 2, py + panel_h / 2)
	love.graphics.scale(panel_anim.scale, panel_anim.scale)
	love.graphics.translate(-(px + panel_w / 2), -(py + panel_h / 2))

	UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.orange, border_width = 2 })

	love.graphics.setFont(Fonts.get(22))
	UI.setColor(UI.colors.orange)
	love.graphics.print("</> DEBUG SETUP", px + 16, py + 12)

	smallBtn("X", px + panel_w - 40, py + 10, 28, 28, UI.colors.red, { 0.95, 0.30, 0.30, 1 })
	registerBtn("close", px + panel_w - 40, py + 10, 28, 28)

	local tab_y = py + 46
	local tab_h = 32
	local tab_x = px + 12
	for _, tab_key in ipairs(tabs) do
		local label = tab_labels[tab_key]
		local tw = Fonts.get(14):getWidth(label) + 24
		local is_active = tab_key == current_tab

		if is_active then
			UI.setColor(UI.colors.orange)
			UI.roundRect("fill", tab_x, tab_y, tw, tab_h, 5)
			love.graphics.setColor(0.06, 0.06, 0.12, 1)
		else
			local mx, my = love.mouse.getPosition()
			if UI.pointInRect(mx, my, tab_x, tab_y, tw, tab_h) then
				UI.setColor(UI.colors.panel_hover)
			else
				UI.setColor(UI.colors.panel_light)
			end
			UI.roundRect("fill", tab_x, tab_y, tw, tab_h, 5)
			UI.setColor(UI.colors.text_dim)
		end

		love.graphics.setFont(Fonts.get(14))
		love.graphics.printf(label, tab_x, tab_y + (tab_h - Fonts.get(14):getHeight()) / 2, tw, "center")
		registerBtn("tab_" .. tab_key, tab_x, tab_y, tw, tab_h)
		tab_x = tab_x + tw + 6
	end

	local content_y = tab_y + tab_h + 10
	local start_btn_h = 48
	local footer_h = start_btn_h + 30
	local content_h = panel_h - (content_y - py) - footer_h

	love.graphics.setScissor(px + 4, content_y, panel_w - 8, content_h)

	if current_tab == "player" then
		drawPlayerTab(px, content_y, panel_w, content_h)
	elseif current_tab == "items" then
		drawItemsTab(px, content_y, panel_w, content_h)
	elseif current_tab == "dice" then
		drawDiceTab(px, content_y, panel_w, content_h)
	elseif current_tab == "stickers" then
		drawStickersTab(px, content_y, panel_w, content_h)
	elseif current_tab == "combos" then
		drawCombinationsTab(px, content_y, panel_w, content_h)
	elseif current_tab == "bosses" then
		drawBossesTab(px, content_y, panel_w, content_h)
	elseif current_tab == "hands" then
		drawHandsTab(px, content_y, panel_w, content_h)
	end

	love.graphics.setScissor()

	local start_btn_w = 260
	local start_btn_x = px + (panel_w - start_btn_w) / 2
	local start_btn_y = py + panel_h - footer_h + 2

	local start_hovered = UI.drawButton(
		"START DEBUG GAME",
		start_btn_x,
		start_btn_y,
		start_btn_w,
		start_btn_h,
		{ font = Fonts.get(20), color = UI.colors.orange, hover_color = { 1.0, 0.70, 0.20, 1 } }
	)
	registerBtn("start_debug", start_btn_x, start_btn_y, start_btn_w, start_btn_h)

	love.graphics.setFont(Fonts.get(11))
	UI.setColor(UI.colors.text_dark)
	love.graphics.printf("Esc to close  |  Click tabs to configure", px, py + panel_h - 20, panel_w, "center")

	love.graphics.pop()
end

function DevMenu:mousepressed(x, y, button)
	if button ~= 1 then
		return nil
	end

	for id, r in pairs(_btn_regions) do
		if UI.pointInRect(x, y, r.x, r.y, r.w, r.h) then
			return self:handleButton(id)
		end
	end

	return nil
end

function DevMenu:handleButton(id)
	if id == "close" then
		anim_init = false
		return "close"
	end

	if id == "start_debug" then
		anim_init = false
		return "start_debug"
	end

	for _, tab_key in ipairs(tabs) do
		if id == "tab_" .. tab_key then
			current_tab = tab_key
			if current_tab == "combos" then
				refreshComboFilter()
			end
			_btn_regions = {}
			return nil
		end
	end

	if id:find("^player_val_") then
		local key = id:sub(12)
		if draft[key] ~= nil then
			active_input = key
			input_buffer = tostring(draft[key])
			input_cursor_blink = 0
		end
		return nil
	end

	if active_input then
		active_input = nil
	end

	if id:find("^player_") then
		local rest = id:sub(8)
		local key, step_str = rest:match("^(.+)_([%-]?%d+)$")
		local step = tonumber(step_str)
		if key and step and draft[key] ~= nil then
			draft[key] = math.max(0, draft[key] + step)
			Toast.show(key .. " = " .. draft[key], "info")
		end
		return nil
	end

	if id:find("^item_") then
		local idx = tonumber(id:sub(6))
		if idx and all_items_ref[idx] then
			local item = all_items_ref[idx]
			local found_idx = nil
			for i, pi in ipairs(draft.items) do
				if pi.name == item.name then
					found_idx = i
					break
				end
			end
			if found_idx then
				table.remove(draft.items, found_idx)
				Toast.show("Removed " .. item.name, "error")
			else
				table.insert(draft.items, item:clone())
				Toast.show("Added " .. item.name, "success")
			end
		end
		return nil
	end

	if id:find("^dice_remove_") then
		local idx = tonumber(id:sub(13))
		if idx and draft.dice_pool[idx] and #draft.dice_pool > 1 then
			local name = draft.dice_pool[idx].name
			table.remove(draft.dice_pool, idx)
			if selected_sticker_die > #draft.dice_pool then
				selected_sticker_die = #draft.dice_pool
			end
			_btn_regions = {}
			Toast.show("Removed " .. name, "error")
		end
		return nil
	end

	if id == "dice_add_broken" then
		local new_die = Die:new({
			name = "Broken Dice",
			color = "black",
			die_type = "broken",
			ability_name = "Broken",
			ability_desc = "This die has shattered. Only rolls 1s.",
			weights = { 1, 0, 0, 0, 0, 0 },
		})
		new_die._sort_order = #draft.dice_pool + 1
		table.insert(draft.dice_pool, new_die)
		_btn_regions = {}
		Toast.show("Added Broken Dice", "success")
		return nil
	end

	if id:find("^dice_add_%d+$") then
		local idx = tonumber(id:sub(10))
		if idx and all_dice_ref[idx] then
			local template = all_dice_ref[idx]
			local new_die = template:clone()
			new_die._sort_order = #draft.dice_pool + 1
			table.insert(draft.dice_pool, new_die)
			_btn_regions = {}
			Toast.show("Added " .. normalizeDiceLabel(new_die.name), "success")
		end
		return nil
	end

	if id == "dice_open_combos" then
		current_tab = "combos"
		refreshComboFilter()
		_btn_regions = {}
		return nil
	end

	if id == "combo_search_box" then
		active_input = "combo_search"
		input_buffer = combo_search_query or ""
		input_cursor_blink = 0
		return nil
	end
	if id == "combo_prev_page" then
		combo_page = math.max(1, combo_page - 1)
		return nil
	end
	if id == "combo_next_page" then
		local max_page = math.max(1, math.ceil(#combo_filtered_indices / combo_page_size))
		combo_page = math.min(max_page, combo_page + 1)
		return nil
	end
	if id:find("^combo_pick_") then
		local idx = tonumber(id:sub(12))
		local entry = idx and combo_catalog and combo_catalog[idx] or nil
		if entry then
			local new_die, err = makeDieFromComboEntry(entry)
			if new_die then
				new_die._sort_order = #draft.dice_pool + 1
				table.insert(draft.dice_pool, new_die)
				selected_sticker_die = #draft.dice_pool
				Toast.show("Added " .. entry.die_name .. " v" .. tostring(entry.value), "success")
			else
				Toast.show(tostring(err or "Cannot add combo die"), "error")
			end
		end
		return nil
	end

	if id == "sticker_die_prev" then
		selected_sticker_die = math.max(1, selected_sticker_die - 1)
		return nil
	end
	if id == "sticker_die_next" then
		selected_sticker_die = math.min(#draft.dice_pool, selected_sticker_die + 1)
		return nil
	end

	if id:find("^sticker_set_") then
		local idx = tonumber(id:sub(13))
		if idx and all_stickers_ref[idx] then
			active_input = id
			local die = draft.dice_pool[selected_sticker_die]
			input_buffer = tostring(die:getStickerStacks(all_stickers_ref[idx].id))
			input_cursor_blink = 0
		end
		return nil
	end

	local function mutateSticker(idx, delta)
		local sticker = all_stickers_ref[idx]
		local die = draft.dice_pool[selected_sticker_die]
		if not sticker or not die then
			return
		end
		local target = math.max(0, die:getStickerStacks(sticker.id) + delta)
		local ok, result = setStickerStacks(die, sticker, target)
		if ok then
			Toast.show(sticker.name .. " x" .. tostring(die:getStickerStacks(sticker.id)), "info")
		else
			Toast.show(tostring(result or "Cannot update sticker"), "error")
		end
	end

	if id:find("^sticker_add5_") then
		local idx = tonumber(id:sub(14))
		if idx then
			mutateSticker(idx, 5)
		end
		return nil
	end
	if id:find("^sticker_add_") then
		local idx = tonumber(id:sub(13))
		if idx then
			mutateSticker(idx, 1)
		end
		return nil
	end
	if id:find("^sticker_sub5_") then
		local idx = tonumber(id:sub(14))
		if idx then
			mutateSticker(idx, -5)
		end
		return nil
	end
	if id:find("^sticker_sub_") then
		local idx = tonumber(id:sub(13))
		if idx then
			mutateSticker(idx, -1)
		end
		return nil
	end

	if id == "boss_clear" then
		selected_boss = nil
		Toast.show("Boss cleared", "info")
		return nil
	end

	if id:find("^boss_force_") then
		local idx = tonumber(id:sub(12))
		if idx and all_bosses_ref[idx] then
			if selected_boss and selected_boss.name == all_bosses_ref[idx].name then
				selected_boss = nil
				Toast.show("Boss cleared", "info")
			else
				selected_boss = all_bosses_ref[idx]
				Toast.show("Selected " .. selected_boss.name, "info")
			end
		end
		return nil
	end

	if id:find("^hand_lvl_") then
		local idx = tonumber(id:sub(10))
		if idx and draft.hands[idx] then
			active_input = id
			input_buffer = tostring(draft.hands[idx].upgrade_level)
			input_cursor_blink = 0
		end
		return nil
	end

	if id:find("^hand_up_") then
		local idx = tonumber(id:sub(9))
		if idx and draft.hands[idx] then
			local hand = draft.hands[idx]
			local new_lvl = hand.upgrade_level + 1
			if new_lvl > hand.max_upgrade then
				hand.max_upgrade = new_lvl
				Toast.show("Requires Limit Breaker in-game", "info")
			end
			hand:setUpgradeLevel(new_lvl)
			Toast.show(hand.name .. " -> Lv" .. hand.upgrade_level, "success")
		end
		return nil
	end

	if id:find("^hand_down_") then
		local idx = tonumber(id:sub(11))
		if idx and draft.hands[idx] then
			local hand = draft.hands[idx]
			if hand.upgrade_level > 0 then
				hand:setUpgradeLevel(hand.upgrade_level - 1)
				Toast.show(hand.name .. " -> Lv" .. hand.upgrade_level, "info")
			end
		end
		return nil
	end

	return nil
end

function DevMenu:textinput(text)
	if not active_input then
		return
	end
	if active_input == "combo_search" then
		if text:match("^[%g ]$") then
			input_buffer = input_buffer .. text
			combo_search_query = input_buffer
			combo_page = 1
			refreshComboFilter()
			input_cursor_blink = 0
		end
		return
	end
	if text:match("^[0-9]$") then
		input_buffer = input_buffer .. text
		input_cursor_blink = 0
	end
end

function DevMenu:keypressed(key)
	if active_input then
		if key == "backspace" then
			input_buffer = input_buffer:sub(1, -2)
			if active_input == "combo_search" then
				combo_search_query = input_buffer
				combo_page = 1
				refreshComboFilter()
			end
			input_cursor_blink = 0
		elseif key == "return" or key == "tab" then
			if active_input == "combo_search" then
				combo_search_query = input_buffer
				combo_page = 1
				refreshComboFilter()
				active_input = nil
				return nil
			end
			local val = tonumber(input_buffer)
			if val then
				local hand_idx = active_input:match("^hand_lvl_(%d+)$")
				if hand_idx then
					hand_idx = tonumber(hand_idx)
					if hand_idx and draft.hands[hand_idx] then
						local hand = draft.hands[hand_idx]
						val = math.max(0, val)
						if val > hand.max_upgrade then
							hand.max_upgrade = val
							Toast.show("Requires Limit Breaker in-game", "info")
						end
						hand:setUpgradeLevel(val)
						Toast.show(hand.name .. " -> Lv" .. hand.upgrade_level, "success")
					end
				else
					local sticker_idx = active_input:match("^sticker_set_(%d+)$")
					if sticker_idx then
						sticker_idx = tonumber(sticker_idx)
						local die = draft.dice_pool[selected_sticker_die]
						local sticker = all_stickers_ref[sticker_idx]
						if die and sticker then
							local ok, result = setStickerStacks(die, sticker, val)
							if ok then
								Toast.show(sticker.name .. " x" .. tostring(die:getStickerStacks(sticker.id)), "success")
							else
								Toast.show(tostring(result or "Cannot update sticker"), "error")
							end
						end
					elseif draft[active_input] ~= nil then
						draft[active_input] = math.max(0, val)
						Toast.show(active_input .. " = " .. draft[active_input], "info")
					end
				end
			end
			active_input = nil
		elseif key == "escape" then
			if active_input == "combo_search" then
				combo_search_query = input_buffer
				combo_page = 1
				refreshComboFilter()
			end
			active_input = nil
		end
		return nil
	end
	if key == "escape" then
		anim_init = false
		return "close"
	end
	if key == "return" then
		anim_init = false
		return "start_debug"
	end
	local tab_idx = nil
	for i, t in ipairs(tabs) do
		if t == current_tab then
			tab_idx = i
			break
		end
	end
	if key == "left" and tab_idx and tab_idx > 1 then
		current_tab = tabs[tab_idx - 1]
		_btn_regions = {}
	elseif key == "right" and tab_idx and tab_idx < #tabs then
		current_tab = tabs[tab_idx + 1]
		_btn_regions = {}
	end
	return nil
end

function DevMenu:drawButton(W, H)
	local btn_w, btn_h = 44, 44
	local bx = W - btn_w - 16
	local by = H - btn_h - 16
	local mx, my = love.mouse.getPosition()
	local hovered = UI.pointInRect(mx, my, bx, by, btn_w, btn_h)

	if hovered then
		UI.setColor(UI.colors.orange)
	else
		love.graphics.setColor(UI.colors.orange[1], UI.colors.orange[2], UI.colors.orange[3], 0.5)
	end
	UI.roundRect("fill", bx, by, btn_w, btn_h, 8)

	love.graphics.setFont(Fonts.get(18))
	love.graphics.setColor(0.06, 0.06, 0.12, 1)
	love.graphics.printf("</>", bx, by + (btn_h - Fonts.get(18):getHeight()) / 2, btn_w, "center")

	self._dev_btn = { x = bx, y = by, w = btn_w, h = btn_h }
	return hovered
end

function DevMenu:isButtonClicked(x, y)
	if self._dev_btn then
		return UI.pointInRect(x, y, self._dev_btn.x, self._dev_btn.y, self._dev_btn.w, self._dev_btn.h)
	end
	return false
end

return DevMenu
