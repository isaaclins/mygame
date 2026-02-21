local UI = require("functions/ui")
local Scoring = require("functions/scoring")
local Fonts = require("functions/fonts")

local Round = {}

local sub_state = "pre_roll"
local pre_roll_timer = 0
local score_display_timer = 0
local round_score = 0
local round_hand = nil
local round_matched = {}
local round_base_score = 0
local round_dice_sum = 0
local round_multiplier = 0
local round_bonus = 0
local round_mult_bonus = 0
local currency_earned = 0
local message = ""
local message_timer = 0
local wild_selecting = false
local wild_die_index = nil
local boss_context = nil
local dice_ability_results = {}
local preview_hand = nil
local preview_score = 0
local preview_bonus = 0
local preview_mult_bonus = 0

local die_colors_map = {
    black = UI.colors.die_black,
    blue  = UI.colors.die_blue,
    green = UI.colors.die_green,
    red   = UI.colors.die_red,
}

function Round:init(player, boss)
    sub_state = "pre_roll"
    pre_roll_timer = 1.0
    score_display_timer = 0
    round_score = 0
    round_hand = nil
    round_matched = {}
    currency_earned = 0
    message = ""
    message_timer = 0
    wild_selecting = false
    wild_die_index = nil
    dice_ability_results = {}

    player:startNewRound()

    boss_context = { player = player }
    if boss then
        boss:applyModifier(boss_context)
    end
end

function Round:update(dt, player)
    message_timer = math.max(0, message_timer - dt)

    if sub_state == "pre_roll" then
        pre_roll_timer = pre_roll_timer - dt
        if pre_roll_timer <= 0 then
            sub_state = "rolling"
            player:rollAllDice()
        end
    elseif sub_state == "rolling" then
        local all_done = player:updateDiceRolls(dt)
        if all_done and not player:anyDiceRolling() then
            if boss_context and boss_context.invert_dice then
                for _, die in ipairs(player.dice_pool) do
                    if not die.locked then
                        die.value = 7 - die.value
                    end
                end
            end

            for _, die in ipairs(player.dice_pool) do
                if die.die_type == "echo" and die.ability then
                    die:triggerAbility({ dice_pool = player.dice_pool })
                end
            end

            sub_state = "choosing"
            self:updatePreview(player)
        end
    elseif sub_state == "rerolling" then
        local all_done = player:updateDiceRolls(dt)
        if all_done and not player:anyDiceRolling() then
            if boss_context and boss_context.invert_dice then
                for _, die in ipairs(player.dice_pool) do
                    if not die.locked then
                        die.value = 7 - die.value
                    end
                end
            end
            sub_state = "choosing"
            self:updatePreview(player)
        end
    elseif sub_state == "scoring" then
        score_display_timer = score_display_timer + dt
    end
end

function Round:draw(player, boss)
    local W, H = love.graphics.getDimensions()

    UI.setColor(UI.colors.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)

    self:drawTopBar(player, boss, W)
    self:drawDice(player, W, H)
    self:drawHandReference(player, W, H)
    self:drawScorePreview(player, W, H)
    self:drawActions(player, W, H)

    if sub_state == "pre_roll" then
        self:drawPreRoll(player, W, H)
    elseif sub_state == "scoring" then
        self:drawScoring(player, W, H)
    end

    if wild_selecting then
        self:drawWildSelector(W, H)
    end

    if message_timer > 0 then
        local alpha = math.min(1, message_timer)
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setFont(Fonts.get(18))
        love.graphics.printf(message, 0, H * 0.45, W, "center")
    end
end

function Round:updatePreview(player)
    if not player or #player.dice_pool == 0 then return end
    local values = player:getDiceValues()
    local context = {
        player = player,
        dice_pool = player.dice_pool,
        scoring = true,
        bonus = 0,
        mult_bonus = 0,
    }

    if not (boss_context and boss_context.suppress_abilities) then
        for _, die in ipairs(player.dice_pool) do
            if die.die_type == "glass" and die.ability then
                context.bonus = context.bonus + 10 + die.upgrade_level * 5
            elseif die.ability and die.die_type ~= "echo" then
                die:triggerAbility(context)
            end
        end
    end

    local saved_triggers = {}
    for i, item in ipairs(player.items) do
        saved_triggers[i] = item.triggered_this_round
    end
    player:applyItems(context)
    for i, item in ipairs(player.items) do
        item.triggered_this_round = saved_triggers[i]
    end

    local hand, score, matched = Scoring.findBestHand(values, player.hands)
    preview_hand = hand
    preview_bonus = context.bonus or 0
    preview_mult_bonus = context.mult_bonus or 0

    score = score + preview_bonus
    if preview_mult_bonus > 0 then
        score = math.floor(score * (1 + preview_mult_bonus))
    end
    preview_score = score
end

function Round:drawScorePreview(player, W, H)
    if sub_state ~= "choosing" or not preview_hand then return end

    local values = player:getDiceValues()
    local _, matched = Scoring.detectHand(values)
    matched = matched or {}
    local dice_sum = 0
    for _, v in ipairs(matched) do
        dice_sum = dice_sum + v
    end

    local has_bonus = preview_bonus > 0
    local has_mult = preview_mult_bonus > 0
    local extra_lines = (has_bonus and 1 or 0) + (has_mult and 1 or 0)

    local panel_x = 10
    local panel_y = 70
    local panel_w = 220
    local panel_h = 148 + extra_lines * 18

    UI.drawPanel(panel_x, panel_y, panel_w, panel_h)

    love.graphics.setFont(Fonts.get(14))
    UI.setColor(UI.colors.text_dim)
    love.graphics.printf("SCORE PREVIEW", panel_x, panel_y + 8, panel_w, "center")

    love.graphics.setFont(Fonts.get(18))
    UI.setColor(UI.colors.accent)
    love.graphics.printf(preview_hand.name, panel_x, panel_y + 28, panel_w, "center")

    love.graphics.setFont(Fonts.get(13))
    local ly = panel_y + 54
    UI.setColor(UI.colors.text_dim)
    love.graphics.printf("Base: " .. preview_hand.base_score, panel_x + 12, ly, panel_w - 24, "left")
    ly = ly + 17
    love.graphics.printf("Dice: +" .. dice_sum, panel_x + 12, ly, panel_w - 24, "left")
    ly = ly + 17
    love.graphics.printf("Mult: ×" .. string.format("%.1f", preview_hand.multiplier), panel_x + 12, ly, panel_w - 24, "left")
    ly = ly + 17

    if has_bonus then
        UI.setColor(UI.colors.green)
        love.graphics.printf("Bonus: +" .. preview_bonus, panel_x + 12, ly, panel_w - 24, "left")
        ly = ly + 17
    end
    if has_mult then
        UI.setColor(UI.colors.green)
        love.graphics.printf("Item mult: ×" .. string.format("%.1f", 1 + preview_mult_bonus), panel_x + 12, ly, panel_w - 24, "left")
        ly = ly + 17
    end

    ly = ly + 2
    love.graphics.setLineWidth(1)
    UI.setColor(UI.colors.text_dark)
    love.graphics.line(panel_x + 12, ly, panel_x + panel_w - 12, ly)

    love.graphics.setFont(Fonts.get(24))
    UI.setColor(UI.colors.text)
    love.graphics.printf(tostring(preview_score), panel_x, ly + 6, panel_w, "center")
end

function Round:drawTopBar(player, boss, W)
    UI.drawPanel(10, 10, W - 20, 50)
    love.graphics.setFont(Fonts.get(18))

    local round_text = "Round " .. player.round
    if player:isBossRound() and boss then
        round_text = round_text .. "  [BOSS: " .. boss.name .. "]"
    end
    UI.setColor(UI.colors.text)
    love.graphics.print(round_text, 24, 22)

    UI.setColor(UI.colors.accent)
    love.graphics.printf("Target: " .. player:getTargetScore(), 0, 22, W * 0.5, "center")

    UI.setColor(UI.colors.green)
    love.graphics.printf("$" .. player.currency, 0, 22, W - 24, "right")

    local reroll_text = "Rerolls: " .. player.rerolls_remaining
    UI.setColor(UI.colors.text_dim)
    love.graphics.printf(reroll_text, 0, 22, W * 0.78, "right")

    if player.seed and #player.seed > 0 then
        love.graphics.setFont(Fonts.get(11))
        UI.setColor(UI.colors.text_dark)
        love.graphics.printf("Seed: " .. player.seed, 0, 42, W * 0.5, "center")
    end
end

function Round:drawDice(player, W, H)
    local die_size = 110
    local gap = 24
    local total_w = #player.dice_pool * die_size + (#player.dice_pool - 1) * gap
    local start_x = (W - total_w) / 2
    local die_y = H * 0.35

    local mx, my = love.mouse.getPosition()

    for i, die in ipairs(player.dice_pool) do
        local dx = start_x + (i - 1) * (die_size + gap)
        local hovered = UI.pointInRect(mx, my, dx, die_y, die_size, die_size)
        local dot_color = die_colors_map[die.color] or UI.colors.die_black

        UI.drawDie(dx, die_y, die_size, die.value, dot_color, nil, die.locked, hovered, die.glow_color)

        love.graphics.setFont(Fonts.get(13))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(die.name, dx, die_y + die_size + 6, die_size, "center")

        if die.ability_name ~= "None" and die.ability_name ~= "Broken" then
            UI.setColor(die.glow_color or UI.colors.accent_dim)
            love.graphics.printf(die.ability_name, dx, die_y + die_size + 22, die_size, "center")
        end
    end
end

function Round:drawHandReference(player, W, H)
    local panel_x = W - 230
    local panel_y = 70
    local panel_w = 220
    local line_h = 22
    local panel_h = #player.hands * line_h + 20

    UI.drawPanel(panel_x, panel_y, panel_w, panel_h)
    love.graphics.setFont(Fonts.get(13))

    for i, hand in ipairs(player.hands) do
        local y = panel_y + 8 + (i - 1) * line_h
        if round_hand and hand.name == round_hand.name then
            UI.setColor(UI.colors.accent)
        else
            UI.setColor(UI.colors.text_dim)
        end
        love.graphics.print(hand.name, panel_x + 10, y)
        love.graphics.printf(hand:getDisplayScore(), panel_x, y, panel_w - 10, "right")
    end
end

function Round:drawActions(player, W, H)
    if sub_state ~= "choosing" then return end

    local btn_w, btn_h = 180, 48
    local btn_y = H * 0.72
    local center_x = W / 2

    self._reroll_hovered = UI.drawButton(
        "REROLL (" .. player.rerolls_remaining .. ")",
        center_x - btn_w - 20, btn_y, btn_w, btn_h,
        {
            font = Fonts.get(20),
            disabled = player.rerolls_remaining <= 0,
            color = UI.colors.blue,
        }
    )

    self._score_hovered = UI.drawButton(
        "SCORE",
        center_x + 20, btn_y, btn_w, btn_h,
        { font = Fonts.get(20), color = UI.colors.green, hover_color = { 0.25, 0.85, 0.45, 1 } }
    )

    love.graphics.setFont(Fonts.get(14))
    UI.setColor(UI.colors.text_dark)
    love.graphics.printf("Click dice to lock/unlock  |  Press 1-5 to toggle  |  R to reroll  |  Enter to score", 0, btn_y + btn_h + 12, W, "center")
end

function Round:drawPreRoll(player, W, H)
    local overlay_alpha = math.min(1, pre_roll_timer)
    love.graphics.setColor(0, 0, 0, overlay_alpha * 0.5)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setFont(Fonts.get(42))
    UI.setColor(UI.colors.text)
    love.graphics.printf("Round " .. player.round, 0, H * 0.35, W, "center")

    love.graphics.setFont(Fonts.get(24))
    UI.setColor(UI.colors.accent)
    love.graphics.printf("Target: " .. player:getTargetScore(), 0, H * 0.35 + 56, W, "center")

    if player:isBossRound() then
        UI.setColor(UI.colors.red)
        love.graphics.printf("BOSS ROUND!", 0, H * 0.35 + 92, W, "center")
    end
end

function Round:drawScoring(player, W, H)
    if score_display_timer < 0.5 then return end

    local panel_w, panel_h = 420, 250
    local px = (W - panel_w) / 2
    local py = H * 0.2

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent, border_width = 2 })

    love.graphics.setFont(Fonts.get(28))
    UI.setColor(UI.colors.accent)
    love.graphics.printf(round_hand and round_hand.name or "No Hand", px, py + 14, panel_w, "center")

    love.graphics.setFont(Fonts.get(14))
    UI.setColor(UI.colors.text_dim)
    local breakdown = "(" .. round_base_score .. " + " .. round_dice_sum .. ") × " .. string.format("%.1f", round_multiplier)
    if round_bonus > 0 then
        breakdown = breakdown .. " + " .. round_bonus .. " bonus"
    end
    if round_mult_bonus > 0 then
        breakdown = breakdown .. " × " .. string.format("%.1f", 1 + round_mult_bonus) .. " item mult"
    end
    love.graphics.printf(breakdown, px, py + 48, panel_w, "center")

    love.graphics.setFont(Fonts.get(42))
    local t = UI.clamp((score_display_timer - 0.5) / 0.8, 0, 1)
    local display_score = math.floor(UI.lerp(0, round_score, t))
    UI.setColor(UI.colors.text)
    love.graphics.printf(tostring(display_score), px, py + 72, panel_w, "center")

    love.graphics.setFont(Fonts.get(18))
    local target = player:getTargetScore()
    if round_score >= target then
        UI.setColor(UI.colors.green)
        love.graphics.printf("TARGET MET! +" .. currency_earned .. " currency", px, py + 128, panel_w, "center")
    else
        UI.setColor(UI.colors.red)
        love.graphics.printf("TARGET MISSED (" .. target .. " needed)", px, py + 128, panel_w, "center")
    end

    if #dice_ability_results > 0 then
        love.graphics.setFont(Fonts.get(13))
        UI.setColor(UI.colors.text_dim)
        local ability_text = table.concat(dice_ability_results, " | ")
        love.graphics.printf(ability_text, px + 10, py + 160, panel_w - 20, "center")
    end

    if score_display_timer > 2.0 then
        if round_score >= target then
            self._continue_hovered = UI.drawButton(
                "CONTINUE", (W - 200) / 2, py + panel_h + 16, 200, 48,
                { font = Fonts.get(20), color = UI.colors.green }
            )
        else
            self._game_over_hovered = UI.drawButton(
                "GAME OVER", (W - 200) / 2, py + panel_h + 16, 200, 48,
                { font = Fonts.get(20), color = UI.colors.red }
            )
        end
    end
end

function Round:drawWildSelector(W, H)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local panel_w, panel_h = 380, 160
    local px = (W - panel_w) / 2
    local py = (H - panel_h) / 2

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent })

    love.graphics.setFont(Fonts.get(20))
    UI.setColor(UI.colors.text)
    love.graphics.printf("Choose Wild Die Value", px, py + 15, panel_w, "center")

    local die_size = 45
    local gap = 12
    local total = 6 * die_size + 5 * gap
    local start_x = px + (panel_w - total) / 2
    local die_y = py + 60

    local mx, my = love.mouse.getPosition()
    self._wild_values = {}

    for v = 1, 6 do
        local dx = start_x + (v - 1) * (die_size + gap)
        local hovered = UI.pointInRect(mx, my, dx, die_y, die_size, die_size)
        UI.drawDie(dx, die_y, die_size, v, UI.colors.die_black, nil, false, hovered, UI.colors.accent)
        self._wild_values[v] = { x = dx, y = die_y, w = die_size, h = die_size }
    end
end

function Round:calculateScore(player)
    local values = player:getDiceValues()
    local context = {
        player = player,
        dice_pool = player.dice_pool,
        scoring = true,
        bonus = 0,
        mult_bonus = 0,
    }

    dice_ability_results = {}
    if not (boss_context and boss_context.suppress_abilities) then
        for _, die in ipairs(player.dice_pool) do
            if die.ability and die.die_type ~= "echo" then
                local result = die:triggerAbility(context)
                if result then
                    table.insert(dice_ability_results, die.name .. ": " .. result)
                end
            end
        end
    end

    player:applyItems(context)

    local hand, score, matched = Scoring.findBestHand(values, player.hands)
    round_hand = hand
    round_matched = matched

    local dice_sum = 0
    for _, v in ipairs(matched) do dice_sum = dice_sum + v end
    round_base_score = hand.base_score
    round_dice_sum = dice_sum
    round_multiplier = hand.multiplier
    round_bonus = context.bonus or 0
    round_mult_bonus = context.mult_bonus or 0

    score = score + round_bonus
    if round_mult_bonus > 0 then
        score = math.floor(score * (1 + round_mult_bonus))
    end

    round_score = score
    return score
end

function Round:mousepressed(x, y, button, player)
    if button ~= 1 then return nil end

    if wild_selecting then
        for v = 1, 6 do
            local rect = self._wild_values and self._wild_values[v]
            if rect and UI.pointInRect(x, y, rect.x, rect.y, rect.w, rect.h) then
                player.dice_pool[wild_die_index].value = v
                player.dice_pool[wild_die_index].wild_choice = v
                wild_selecting = false
                wild_die_index = nil
                self:updatePreview(player)
                return nil
            end
        end
        return nil
    end

    if sub_state == "choosing" then
        local W, H = love.graphics.getDimensions()
        local die_size = 110
        local gap = 24
        local total_w = #player.dice_pool * die_size + (#player.dice_pool - 1) * gap
        local start_x = (W - total_w) / 2
        local die_y = H * 0.35

        for i, die in ipairs(player.dice_pool) do
            local dx = start_x + (i - 1) * (die_size + gap)
            if UI.pointInRect(x, y, dx, die_y, die_size, die_size) then
                if boss_context and boss_context.locked_by_boss == i then
                    message = "Boss locked this die!"
                    message_timer = 1.5
                    return nil
                end

                if die.die_type == "wild" and not die.locked then
                    wild_selecting = true
                    wild_die_index = i
                    return nil
                end

                player:lockDie(i)
                self:updatePreview(player)
                return nil
            end
        end

        if self._reroll_hovered and player.rerolls_remaining > 0 then
            player:rerollUnlocked()
            sub_state = "rerolling"
            return nil
        end

        if self._score_hovered then
            local score = self:calculateScore(player)
            sub_state = "scoring"
            score_display_timer = 0

            if score >= player:getTargetScore() then
                currency_earned = player:earnCurrency(score)
                local earn_context = { player = player, phase = "earn" }
                player:applyItems(earn_context)
            end
            return nil
        end
    end

    if sub_state == "scoring" and score_display_timer > 2.0 then
        local target = player:getTargetScore()
        if round_score >= target then
            if self._continue_hovered then
                return "to_shop"
            end
        else
            if self._game_over_hovered then
                return "game_over"
            end
        end
    end

    return nil
end

function Round:keypressed(key, player)
    if wild_selecting and key == "escape" then
        wild_selecting = false
        wild_die_index = nil
        return "handled"
    end

    if sub_state == "choosing" then
        if key == "r" and player.rerolls_remaining > 0 then
            player:rerollUnlocked()
            sub_state = "rerolling"
        elseif key == "s" or key == "return" then
            local score = self:calculateScore(player)
            sub_state = "scoring"
            score_display_timer = 0
            if score >= player:getTargetScore() then
                currency_earned = player:earnCurrency(score)
                local earn_context = { player = player, phase = "earn" }
                player:applyItems(earn_context)
            end
        elseif tonumber(key) then
            local idx = tonumber(key)
            if idx >= 1 and idx <= #player.dice_pool then
                if boss_context and boss_context.locked_by_boss == idx then
                    message = "Boss locked this die!"
                    message_timer = 1.5
                else
                    player:lockDie(idx)
                    self:updatePreview(player)
                end
            end
        end
    elseif sub_state == "scoring" and score_display_timer > 2.0 then
        if key == "return" or key == "space" then
            if round_score >= player:getTargetScore() then
                return "to_shop"
            else
                return "game_over"
            end
        end
    end
    return nil
end

function Round:getBossContext()
    return boss_context
end

return Round
