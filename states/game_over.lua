local UI = require("functions/ui")
local Fonts = require("functions/fonts")
local Tween = require("functions/tween")
local Particles = require("functions/particles")
local CoinAnim = require("functions/coin_anim")

local GameOver = {}

local time_elapsed = 0
local title_anim = { y = 0, scale = 1, alpha = 0 }
local stats_anims = {}
local seed_anim = { alpha = 0 }
local btn_anims = {}
local shake = { x = 0, y = 0, intensity = 0 }
local drift_spawned = false
local go_focus = 1

function GameOver:init()
	time_elapsed = 0
	drift_spawned = false
	go_focus = 1

	title_anim = { y = -200, scale = 2.0, alpha = 0 }
	Tween.to(title_anim, 0.7, { y = 0, scale = 1.0, alpha = 1 }, "outElastic", function()
		shake.intensity = 10
	end)

	stats_anims = {}
	for i = 1, 5 do
		stats_anims[i] = { alpha = 0, y_off = 20, count_val = 0 }
	end

	seed_anim = { alpha = 0 }

	btn_anims = {}
	for i = 1, 2 do
		btn_anims[i] = { alpha = 0, y_off = 30 }
	end
end

function GameOver:update(dt)
	time_elapsed = time_elapsed + dt

	if shake.intensity > 0 then
		shake.intensity = shake.intensity * (1 - dt * 6)
		shake.x = (math.random() - 0.5) * shake.intensity * 2
		shake.y = (math.random() - 0.5) * shake.intensity * 2
		if shake.intensity < 0.3 then
			shake.intensity = 0
			shake.x = 0
			shake.y = 0
		end
	end

	for i, sa in ipairs(stats_anims) do
		local reveal_at = 0.8 + (i - 1) * 0.3
		if time_elapsed > reveal_at and sa.alpha < 1 then
			sa.alpha = math.min(1, sa.alpha + dt * 4)
			sa.y_off = sa.y_off * math.max(0, 1 - dt * 8)
		end
	end

	local seed_reveal = 0.8 + #stats_anims * 0.3
	if time_elapsed > seed_reveal then
		seed_anim.alpha = math.min(1, seed_anim.alpha + dt * 3)
	end

	local btn_reveal = seed_reveal + 0.4
	for i, ba in ipairs(btn_anims) do
		local at = btn_reveal + (i - 1) * 0.15
		if time_elapsed > at and ba.alpha < 1 then
			ba.alpha = math.min(1, ba.alpha + dt * 4)
			ba.y_off = ba.y_off * math.max(0, 1 - dt * 8)
		end
	end

	if not drift_spawned and time_elapsed > 0.5 then
		drift_spawned = true
		local W, H = love.graphics.getDimensions()
		Particles.drift(0, 0, W, H, { 0.9, 0.15, 0.15, 0.25 }, 40)
	end
end

function GameOver:draw(player)
	local W, H = love.graphics.getDimensions()

	love.graphics.push()
	love.graphics.translate(shake.x, shake.y)

	love.graphics.setColor(0.03, 0.03, 0.06, 1)
	love.graphics.rectangle("fill", 0, 0, W, H)

	love.graphics.setColor(0.9, 0.15, 0.15, 0.04)
	for i = 1, 6 do
		local r = 40 + i * 50 + math.sin(time_elapsed * 0.5 + i) * 15
		love.graphics.circle("fill", W / 2, H * 0.3, r)
	end

	love.graphics.push()
	love.graphics.translate(W / 2, H * 0.18 + title_anim.y + 26)
	love.graphics.scale(title_anim.scale, title_anim.scale)
	love.graphics.setFont(Fonts.get(52))

	love.graphics.setColor(0.9, 0.12, 0.12, title_anim.alpha * 0.2)
	for dx = -2, 2 do
		for dy = -2, 2 do
			if dx ~= 0 or dy ~= 0 then
				love.graphics.printf("GAME OVER", dx - W / 2, dy - 26, W, "center")
			end
		end
	end

	love.graphics.setColor(0.9, 0.15, 0.15, title_anim.alpha)
	love.graphics.printf("GAME OVER", -W / 2, -26, W, "center")
	love.graphics.pop()

	local stats_y = H * 0.38
	love.graphics.setFont(Fonts.get(22))

	local sa1 = stats_anims[1]
	if sa1.alpha > 0 then
		local count_t = math.min(1, (time_elapsed - 1.1) / 0.5)
		local display_round = math.floor(UI.lerp(0, player.round, math.max(0, count_t)))
		love.graphics.setColor(1, 1, 1, sa1.alpha)
		love.graphics.printf("Round Reached: " .. display_round, 0, stats_y + sa1.y_off, W, "center")
	end

	local sa2 = stats_anims[2]
	if sa2.alpha > 0 then
		local count_t = math.min(1, (time_elapsed - 1.4) / 0.5)
		local display_currency = math.floor(UI.lerp(0, player.currency, math.max(0, count_t)))
		love.graphics.setColor(1, 1, 1, sa2.alpha)
		local fc_font = love.graphics.getFont()
		local fc_label = "Final Currency: "
		local fc_amount = UI.abbreviate(display_currency)
		local fc_cs = fc_font:getHeight() / CoinAnim.getHeight()
		local fc_coin_w = CoinAnim.getWidth(fc_cs)
		local fc_gap = math.max(1, math.floor(2 * fc_cs))
		local fc_total_w = fc_font:getWidth(fc_label) + fc_coin_w + fc_gap + fc_font:getWidth(fc_amount)
		local fc_x = (W - fc_total_w) / 2
		local fc_y = stats_y + 36 + sa2.y_off
		love.graphics.print(fc_label, fc_x, fc_y)
		local fc_coin_x = fc_x + fc_font:getWidth(fc_label)
		local fc_coin_y = fc_y + (fc_font:getHeight() - CoinAnim.getHeight(fc_cs)) / 2
		love.graphics.setColor(1, 1, 1, sa2.alpha)
		CoinAnim.drawStatic(fc_coin_x, fc_coin_y, fc_cs)
		love.graphics.setColor(1, 1, 1, sa2.alpha)
		love.graphics.print(fc_amount, fc_coin_x + fc_coin_w + fc_gap, fc_y)
	end

	local sa3 = stats_anims[3]
	if sa3.alpha > 0 then
		love.graphics.setColor(1, 1, 1, sa3.alpha)
		love.graphics.printf("Dice Pool:", 0, stats_y + 72 + sa3.y_off, W, "center")
	end

	local sa4 = stats_anims[4]
	if sa4.alpha > 0 then
		local die_names = {}
		for _, die in ipairs(player.dice_pool) do
			table.insert(die_names, die.name)
		end
		love.graphics.setFont(Fonts.get(18))
		love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], sa4.alpha)
		love.graphics.printf(table.concat(die_names, ", "), W * 0.15, stats_y + 100 + sa4.y_off, W * 0.7, "center")
	end

	local sa5 = stats_anims[5]
	if sa5 and sa5.alpha > 0 then
		local item_names = {}
		for _, item in ipairs(player.items) do
			table.insert(item_names, item.name)
		end
		for di, die in ipairs(player.dice_pool) do
			for _, item in ipairs(die.items or {}) do
				table.insert(item_names, "D" .. di .. ":" .. item.name)
			end
		end
		if #item_names == 0 then
			goto continue_stats
		end
		love.graphics.setFont(Fonts.get(18))
		love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], sa5.alpha)
		love.graphics.printf(
			"Relics & Die Mods: " .. table.concat(item_names, ", "),
			W * 0.15,
			stats_y + 130 + sa5.y_off,
			W * 0.7,
			"center"
		)
		::continue_stats::
	end

	if seed_anim.alpha > 0 and player.seed and #player.seed > 0 then
		love.graphics.setFont(Fonts.get(16))
		love.graphics.setColor(
			UI.colors.accent_dim[1],
			UI.colors.accent_dim[2],
			UI.colors.accent_dim[3],
			seed_anim.alpha
		)
		love.graphics.printf("Seed: " .. player.seed, 0, stats_y + 170, W, "center")
	end

	local btn_w, btn_h = 260, 56
	local ba1 = btn_anims[1]
	if ba1.alpha > 0 then
		self._retry_hovered = UI.drawButton(
			"PLAY AGAIN",
			(W - btn_w) / 2,
			H * 0.78 + ba1.y_off,
			btn_w,
			btn_h,
			{ font = Fonts.get(24), color = UI.colors.blue }
		)
		if go_focus == 1 then
			UI.drawFocusRect((W - btn_w) / 2, H * 0.78 + ba1.y_off, btn_w, btn_h)
		end
	else
		self._retry_hovered = false
	end

	local ba2 = btn_anims[2]
	if ba2.alpha > 0 then
		self._menu_hovered = UI.drawButton(
			"MENU",
			(W - btn_w) / 2,
			H * 0.78 + 70 + ba2.y_off,
			btn_w,
			btn_h,
			{ font = Fonts.get(24), color = UI.colors.panel_light, hover_color = UI.colors.panel_hover }
		)
		if go_focus == 2 then
			UI.drawFocusRect((W - btn_w) / 2, H * 0.78 + 70 + ba2.y_off, btn_w, btn_h)
		end
	else
		self._menu_hovered = false
	end

	love.graphics.pop()
end

function GameOver:mousepressed(x, y, button)
	if button ~= 1 then
		return nil
	end

	if self._retry_hovered then
		return "start_game"
	elseif self._menu_hovered then
		return "restart"
	end
	return nil
end

function GameOver:keypressed(key)
	if time_elapsed < 2.0 then
		return nil
	end
	if key == "up" or key == "down" then
		go_focus = go_focus == 1 and 2 or 1
		return nil
	elseif key == "return" or key == "space" then
		return go_focus == 1 and "start_game" or "restart"
	elseif key == "escape" then
		return "restart"
	end
	return nil
end

return GameOver
