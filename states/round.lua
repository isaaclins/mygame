local UI = require("functions/ui")
local Scoring = require("functions/scoring")
local Fonts = require("functions/fonts")
local Tween = require("functions/tween")
local Particles = require("functions/particles")
local Toast = require("functions/toast")
local Settings = require("functions/settings")
local Tutorial = require("states/tutorial")

local Round = {}

local sort_modes = {
    { key = "default",    label = "Default" },
    { key = "value_asc",  label = "Val 1-6" },
    { key = "value_desc", label = "Val 6-1" },
    { key = "type",       label = "Type" },
    { key = "even_first", label = "Even 1st" },
    { key = "odd_first",  label = "Odd 1st" },
}

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
local wild_selecting = false
local wild_die_index = nil
local boss_context = nil
local dice_ability_results = {}
local preview_hand = nil
local preview_score = 0
local preview_bonus = 0
local preview_mult_bonus = 0
local selected_die_index = nil
local tooltip_visible = true

local die_anims = {}
local pre_roll_anim = { scale = 0, alpha = 0, target_count = 0 }
local score_panel_anim = { alpha = 0, scale = 0.8 }
local preview_panel_anim = { x_off = -240, alpha = 0 }
local hand_ref_anim = { x_off = 240, alpha = 0 }
local scoring_shake = { x = 0, y = 0, intensity = 0 }
local score_countup = { value = 0 }
local shown_preview = false
local shown_hand_ref = false

local die_colors_map = {
    black = UI.colors.die_black,
    blue  = UI.colors.die_blue,
    green = UI.colors.die_green,
    red   = UI.colors.die_red,
}

local function resetDieAnims(player)
    die_anims = {}
    for i = 1, #player.dice_pool do
        die_anims[i] = {
            hover_scale = 1,
            y_off = 0,
            lock_flash = 0,
            bounce = 0,
            pop_scale = 1,
            echo_flash = 0,
        }
    end
end

local function getKeybind(action)
    return Settings.get("keybind_" .. action)
end

local function isKey(key, action)
    return key == getKeybind(action)
end

function Round:init(player, boss)
    sub_state = "pre_roll"
    pre_roll_timer = 1.2
    score_display_timer = 0
    round_score = 0
    round_hand = nil
    round_matched = {}
    currency_earned = 0
    wild_selecting = false
    wild_die_index = nil
    dice_ability_results = {}
    preview_hand = nil
    shown_preview = false
    shown_hand_ref = false
    selected_die_index = nil

    player:startNewRound()

    boss_context = { player = player }
    if boss then
        boss:applyModifier(boss_context)
    end

    resetDieAnims(player)

    pre_roll_anim = { scale = 2.0, alpha = 0, target_count = 0 }
    Tween.to(pre_roll_anim, 0.5, { scale = 1.0, alpha = 1 }, "outElastic")

    score_panel_anim = { alpha = 0, scale = 0.8 }
    preview_panel_anim = { x_off = -240, alpha = 0 }
    hand_ref_anim = { x_off = 240, alpha = 0 }
    scoring_shake = { x = 0, y = 0, intensity = 0 }
    score_countup = { value = 0 }
end

function Round:update(dt, player)
    if scoring_shake.intensity > 0 then
        scoring_shake.intensity = scoring_shake.intensity * (1 - dt * 8)
        scoring_shake.x = (math.random() - 0.5) * scoring_shake.intensity * 2
        scoring_shake.y = (math.random() - 0.5) * scoring_shake.intensity * 2
        if scoring_shake.intensity < 0.3 then
            scoring_shake.intensity = 0
            scoring_shake.x = 0
            scoring_shake.y = 0
        end
    end

    local mx, my = love.mouse.getPosition()
    local W, H = love.graphics.getDimensions()
    local count = #player.dice_pool
    if count > 0 then
        local layout = getDiceLayout(count, W, H)
        for i, da in ipairs(die_anims) do
            local dx, dy = getDiePosition(layout, i, count)
            local hovered = UI.pointInRect(mx, my, dx, dy, layout.die_size, layout.die_size)
            local target_scale = hovered and 1.08 or 1.0
            local target_y = hovered and -4 or 0
            da.hover_scale = da.hover_scale + (target_scale - da.hover_scale) * math.min(1, 10 * dt)
            da.y_off = da.y_off + (target_y - da.y_off) * math.min(1, 10 * dt)
            da.lock_flash = math.max(0, da.lock_flash - dt * 4)
            da.bounce = da.bounce * math.max(0, 1 - dt * 6)
            da.pop_scale = da.pop_scale + (1.0 - da.pop_scale) * math.min(1, 8 * dt)
            da.echo_flash = math.max(0, (da.echo_flash or 0) - dt * 1.8)
        end
    end

    if sub_state == "pre_roll" then
        pre_roll_timer = pre_roll_timer - dt
        local target = player:getTargetScore()
        local progress = 1 - math.max(0, pre_roll_timer / 1.2)
        pre_roll_anim.target_count = math.floor(target * math.min(1, progress * 2))
        if pre_roll_timer <= 0 then
            sub_state = "rolling"
            player:rollAllDice()
        end
    elseif sub_state == "rolling" then
        local all_done = player:updateDiceRolls(dt)
        if all_done and not player:anyDiceRolling() then
            if boss_context and boss_context.invert_dice then
                for _, die in ipairs(player.dice_pool) do
                    if not die.locked then die.value = 7 - die.value end
                end
            end
            for i, die in ipairs(player.dice_pool) do
                if die.die_type == "echo" and die.ability then
                    local result = die:triggerAbility({ dice_pool = player.dice_pool })
                    if result == "echo" and die_anims[i] then
                        die_anims[i].echo_flash = 1.0
                        die_anims[i].pop_scale = 1.2
                        die_anims[i].bounce = 8
                    end
                end
            end

            for i, da in ipairs(die_anims) do
                da.bounce = math.max(da.bounce, 6)
                da.pop_scale = math.max(da.pop_scale, 1.12)
            end

            sub_state = "choosing"
            self:applySortMode(player)
            self:updatePreview(player)
            self:slideInPanels()
            if Tutorial:isActive() then Tutorial:notifySubState("choosing") end
        end
    elseif sub_state == "rerolling" then
        local all_done = player:updateDiceRolls(dt)
        if all_done and not player:anyDiceRolling() then
            if boss_context and boss_context.invert_dice then
                for _, die in ipairs(player.dice_pool) do
                    if not die.locked then die.value = 7 - die.value end
                end
            end
            for i, die in ipairs(player.dice_pool) do
                if not die.locked and die.die_type == "echo" and die.ability then
                    local result = die:triggerAbility({ dice_pool = player.dice_pool })
                    if result == "echo" and die_anims[i] then
                        die_anims[i].echo_flash = 1.0
                        die_anims[i].pop_scale = 1.2
                        die_anims[i].bounce = 8
                    end
                end
            end
            for i, die in ipairs(player.dice_pool) do
                if not die.locked then
                    local da = die_anims[i]
                    if da then
                        da.bounce = 5
                        da.pop_scale = 1.1
                    end
                end
            end
            sub_state = "choosing"
            self:applySortMode(player)
            self:updatePreview(player)
        end
    elseif sub_state == "scoring" then
        score_display_timer = score_display_timer + dt
        if Tutorial:isActive() then
            Tutorial:notifySubState("scoring", { timer = score_display_timer })
        end
    end
end

function Round:slideInPanels()
    if not shown_preview then
        shown_preview = true
        preview_panel_anim = { x_off = -240, alpha = 0 }
        Tween.to(preview_panel_anim, 0.4, { x_off = 0, alpha = 1 }, "outCubic")
    end
    if not shown_hand_ref then
        shown_hand_ref = true
        hand_ref_anim = { x_off = 240, alpha = 0 }
        Tween.to(hand_ref_anim, 0.4, { x_off = 0, alpha = 1 }, "outCubic")
    end
end

function Round:applySortMode(player)
    local mode = Settings.get("dice_sort_mode") or "default"
    player:sortDice(mode)
    resetDieAnims(player)
end

function Round:draw(player, boss)
    local W, H = love.graphics.getDimensions()

    love.graphics.push()
    love.graphics.translate(scoring_shake.x, scoring_shake.y)

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

    love.graphics.pop()
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
    if preview_panel_anim.alpha < 0.01 then return end

    local values = player:getDiceValues()
    local _, matched = Scoring.detectHand(values)
    matched = matched or {}
    local dice_sum = 0
    for _, v in ipairs(matched) do dice_sum = dice_sum + v end

    local has_bonus = preview_bonus > 0
    local has_mult = preview_mult_bonus > 0
    local extra_lines = (has_bonus and 1 or 0) + (has_mult and 1 or 0)

    local panel_x = 10 + preview_panel_anim.x_off
    local panel_y = 70
    local panel_w = 220
    local panel_h = 152 + extra_lines * 18

    love.graphics.setColor(1, 1, 1, preview_panel_anim.alpha)
    UI.drawPanel(panel_x, panel_y, panel_w, panel_h)

    love.graphics.setFont(Fonts.get(12))
    love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], preview_panel_anim.alpha)
    love.graphics.printf("SCORE PREVIEW", panel_x, panel_y + 8, panel_w, "center")

    love.graphics.setFont(Fonts.get(18))
    local shimmer = 0.8 + 0.2 * math.sin(love.timer.getTime() * 3)
    love.graphics.setColor(UI.colors.accent[1] * shimmer, UI.colors.accent[2] * shimmer, UI.colors.accent[3], preview_panel_anim.alpha)
    love.graphics.printf(preview_hand.name, panel_x, panel_y + 26, panel_w, "center")

    love.graphics.setFont(Fonts.get(13))
    local ly = panel_y + 52
    love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], preview_panel_anim.alpha * 0.9)
    love.graphics.printf("Base: " .. preview_hand.base_score, panel_x + 12, ly, panel_w - 24, "left")
    ly = ly + 17
    love.graphics.printf("Dice: +" .. dice_sum, panel_x + 12, ly, panel_w - 24, "left")
    ly = ly + 17
    love.graphics.printf("Mult: x" .. string.format("%.1f", preview_hand.multiplier), panel_x + 12, ly, panel_w - 24, "left")
    ly = ly + 17

    if has_bonus then
        love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], preview_panel_anim.alpha)
        love.graphics.printf("Bonus: +" .. preview_bonus, panel_x + 12, ly, panel_w - 24, "left")
        ly = ly + 17
    end
    if has_mult then
        love.graphics.setColor(UI.colors.green[1], UI.colors.green[2], UI.colors.green[3], preview_panel_anim.alpha)
        love.graphics.printf("Item mult: x" .. string.format("%.1f", 1 + preview_mult_bonus), panel_x + 12, ly, panel_w - 24, "left")
        ly = ly + 17
    end

    ly = ly + 2
    love.graphics.setLineWidth(1)
    love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], preview_panel_anim.alpha * 0.6)
    love.graphics.line(panel_x + 12, ly, panel_x + panel_w - 12, ly)

    love.graphics.setFont(Fonts.get(24))
    love.graphics.setColor(1, 1, 1, preview_panel_anim.alpha)
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

function getDiceLayout(count, W, H)
    local left_margin = 240
    local right_margin = 240
    local avail_w = W - left_margin - right_margin

    local die_size = math.min(110, math.max(60, math.floor(avail_w / math.min(count, 6)) - 16))
    local gap = math.min(16, math.max(8, math.floor((avail_w - die_size * math.min(count, 6)) / math.max(math.min(count, 6) - 1, 1))))

    local per_row = math.max(1, math.floor((avail_w + gap) / (die_size + gap)))
    local rows = math.ceil(count / per_row)
    local label_font = die_size >= 90 and 13 or (die_size >= 70 and 11 or 9)
    local row_h = die_size + label_font + 22
    local base_y = H * 0.35 - (rows - 1) * row_h / 2

    return {
        die_size = die_size, gap = gap, per_row = per_row,
        rows = rows, label_font = label_font, row_h = row_h,
        base_y = base_y, left_margin = left_margin, avail_w = avail_w,
    }
end

function getDiePosition(layout, i, count)
    local row = math.floor((i - 1) / layout.per_row)
    local col = (i - 1) % layout.per_row
    local items_in_row = math.min(layout.per_row, count - row * layout.per_row)
    local row_w = items_in_row * layout.die_size + (items_in_row - 1) * layout.gap
    local row_x = layout.left_margin + (layout.avail_w - row_w) / 2
    local dx = row_x + col * (layout.die_size + layout.gap)
    local dy = layout.base_y + row * layout.row_h
    return dx, dy
end

function Round:drawDice(player, W, H)
    local count = #player.dice_pool
    local layout = getDiceLayout(count, W, H)
    local mx, my = love.mouse.getPosition()
    local t = love.timer.getTime()

    local tooltip_die = nil
    local tooltip_dx, tooltip_dy, tooltip_s = 0, 0, 0

    local die_matched = {}
    if sub_state == "choosing" and preview_hand then
        local values = player:getDiceValues()
        local _, matched = Scoring.detectHand(values)
        matched = matched or {}
        local match_counts = {}
        for _, v in ipairs(matched) do
            match_counts[v] = (match_counts[v] or 0) + 1
        end
        for i, die in ipairs(player.dice_pool) do
            local v = die.value
            if match_counts[v] and match_counts[v] > 0 then
                die_matched[i] = true
                match_counts[v] = match_counts[v] - 1
            end
        end
    end

    for i, die in ipairs(player.dice_pool) do
        local dx, dy = getDiePosition(layout, i, count)
        local da = die_anims[i] or { hover_scale = 1, y_off = 0, lock_flash = 0, bounce = 0, pop_scale = 1 }
        local hovered = UI.pointInRect(mx, my, dx - 4, dy - 4, layout.die_size + 8, layout.die_size + 8)
        local dot_color = die_colors_map[die.color] or UI.colors.die_black
        local is_selected = (i == selected_die_index and sub_state == "choosing")

        local sel_float = 0
        if is_selected then
            sel_float = -4 - 3 * math.sin(t * 3)
        end

        local scale = da.hover_scale * da.pop_scale
        local s = layout.die_size * scale
        local cx = dx + layout.die_size / 2
        local cy = dy + layout.die_size / 2
        local draw_x = cx - s / 2
        local draw_y = cy - s / 2 + da.y_off + math.sin(t * 12 + i) * da.bounce + sel_float

        if is_selected then
            local pulse = 0.5 + 0.5 * math.sin(t * 4)
            love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.15 + 0.1 * pulse)
            UI.roundRect("fill", draw_x - 6, draw_y - 6, s + 12, s + 12, s * 0.15 + 4)
        end

        local is_boss_locked = boss_context and boss_context.boss_locked_die == die
        UI.drawDie(draw_x, draw_y, s, die.value, dot_color, nil, die.locked, hovered, die.glow_color, is_boss_locked)

        if is_selected then
            local pulse = 0.5 + 0.5 * math.sin(t * 4)
            love.graphics.setLineWidth(2.5)
            love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 0.6 + 0.3 * pulse)
            UI.roundRect("line", draw_x - 3, draw_y - 3, s + 6, s + 6, s * 0.15 + 2)
            love.graphics.setLineWidth(1)
        end

        if da.lock_flash > 0 then
            love.graphics.setColor(1, 0.3, 0.3, da.lock_flash * 0.3)
            UI.roundRect("fill", draw_x, draw_y, s, s, s * 0.15)
        end

        if (da.echo_flash or 0) > 0 then
            local ef = da.echo_flash
            local ring_expand = (1 - ef) * s * 0.4
            love.graphics.setColor(0.3, 0.7, 0.9, ef * 0.5)
            UI.roundRect("fill", draw_x - ring_expand / 2, draw_y - ring_expand / 2,
                s + ring_expand, s + ring_expand, s * 0.15 + ring_expand * 0.3)
            love.graphics.setLineWidth(2)
            love.graphics.setColor(0.3, 0.7, 0.9, ef * 0.8)
            UI.roundRect("line", draw_x - ring_expand / 2, draw_y - ring_expand / 2,
                s + ring_expand, s + ring_expand, s * 0.15 + ring_expand * 0.3)
            love.graphics.setLineWidth(1)
        end

        love.graphics.setFont(Fonts.get(layout.label_font))
        UI.setColor(UI.colors.text_dim)
        love.graphics.printf(die.name, dx - 4, dy + layout.die_size + 4, layout.die_size + 8, "center")

        if die.ability_name ~= "None" and die.ability_name ~= "Broken" then
            UI.setColor(die.glow_color or UI.colors.accent_dim)
            love.graphics.printf(die.ability_name, dx - 4, dy + layout.die_size + 4 + layout.label_font + 2, layout.die_size + 8, "center")
        end

        if sub_state == "choosing" then
            local show_for_hover = hovered
            local show_for_select = is_selected and tooltip_visible
            if show_for_hover or show_for_select then
                tooltip_die = { die = die, index = i, matched = die_matched[i], boss_locked = is_boss_locked }
                tooltip_dx = draw_x
                tooltip_dy = draw_y
                tooltip_s = s
            end
        end
    end

    if tooltip_die and preview_hand then
        self:drawDieTooltip(tooltip_die, tooltip_dx, tooltip_dy, tooltip_s, W, H)
    end
end

function Round:drawDieTooltip(info, dx, dy, s, W, H)
    local die = info.die
    local is_matched = info.matched

    local tip_w = 210
    local pad = 10

    local has_ability = die.ability_name ~= "None" and die.ability_name ~= "Broken"
    local desc_font = Fonts.get(11)
    local desc_lines = 0
    if has_ability and die.ability_desc and #die.ability_desc > 0 then
        local _, wraps = desc_font:getWrap(die.ability_desc, tip_w - pad * 2)
        desc_lines = #wraps
    end

    local tip_h = pad + 20
        + (has_ability and (16 + desc_lines * 13 + 6) or 0)
        + 2 + 18
        + (preview_hand and 18 or 0)
        + pad

    local tip_x = dx + s / 2 - tip_w / 2
    tip_x = math.max(8, math.min(tip_x, W - tip_w - 8))
    local tip_y = dy - tip_h - 10
    if tip_y < 65 then
        tip_y = dy + s + 10
    end

    love.graphics.setColor(0.08, 0.08, 0.16, 0.95)
    UI.roundRect("fill", tip_x, tip_y, tip_w, tip_h, 8)

    local border_color = die.glow_color or UI.colors.accent
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], (border_color[4] or 1) * 0.8)
    UI.roundRect("line", tip_x, tip_y, tip_w, tip_h, 8)
    love.graphics.setLineWidth(1)

    local ly = tip_y + pad

    love.graphics.setFont(Fonts.get(15))
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], border_color[4] or 1)
    love.graphics.printf(die.name, tip_x + pad, ly, tip_w - pad * 2, "center")
    ly = ly + 20

    if has_ability then
        love.graphics.setFont(Fonts.get(12))
        love.graphics.setColor(border_color[1], border_color[2], border_color[3], (border_color[4] or 1) * 0.7)
        love.graphics.printf(die.ability_name, tip_x + pad, ly, tip_w - pad * 2, "center")
        ly = ly + 16

        if die.ability_desc and #die.ability_desc > 0 then
            love.graphics.setFont(desc_font)
            UI.setColor(UI.colors.text_dim)
            love.graphics.printf(die.ability_desc, tip_x + pad, ly, tip_w - pad * 2, "left")
            ly = ly + desc_lines * 13
        end
        ly = ly + 6
    end

    love.graphics.setColor(UI.colors.text_dark[1], UI.colors.text_dark[2], UI.colors.text_dark[3], 0.5)
    love.graphics.line(tip_x + pad, ly, tip_x + tip_w - pad, ly)
    ly = ly + 4

    love.graphics.setFont(Fonts.get(13))
    UI.setColor(UI.colors.text)
    love.graphics.printf("Value: " .. die.value, tip_x + pad, ly, tip_w - pad * 2, "left")

    if die.locked then
        if info.boss_locked then
            UI.setColor(UI.colors.purple)
            love.graphics.printf("BOSS LOCKED", tip_x + pad, ly, tip_w - pad * 2, "right")
        else
            UI.setColor(UI.colors.red)
            love.graphics.printf("LOCKED", tip_x + pad, ly, tip_w - pad * 2, "right")
        end
    end
    ly = ly + 18

    if preview_hand then
        if is_matched then
            UI.setColor(UI.colors.green)
            love.graphics.printf("Matched (+" .. die.value .. " to hand)", tip_x + pad, ly, tip_w - pad * 2, "left")
        else
            UI.setColor(UI.colors.text_dark)
            love.graphics.printf("Not matched", tip_x + pad, ly, tip_w - pad * 2, "left")
        end
    end
end

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

function Round:drawHandReference(player, W, H)
    if hand_ref_anim.alpha < 0.01 then return end

    local dice_count = #player.dice_pool
    local visible_hands = {}
    for _, hand in ipairs(player.hands) do
        if (hand.min_dice or 1) <= dice_count then
            table.insert(visible_hands, hand)
        end
    end

    local panel_x = W - 230 + hand_ref_anim.x_off
    local panel_y = 70
    local panel_w = 220
    local line_h = #visible_hands > 12 and 18 or 22
    local font_size = #visible_hands > 12 and 11 or 13
    local panel_h = #visible_hands * line_h + 20

    love.graphics.setColor(1, 1, 1, hand_ref_anim.alpha)
    UI.drawPanel(panel_x, panel_y, panel_w, panel_h)
    love.graphics.setFont(Fonts.get(font_size))

    local mx, my = love.mouse.getPosition()
    local hovered_hand = nil

    for i, hand in ipairs(visible_hands) do
        local y = panel_y + 8 + (i - 1) * line_h
        local is_hovered = UI.pointInRect(mx, my, panel_x, y, panel_w, line_h)

        if is_hovered then
            love.graphics.setColor(1, 1, 1, 0.06 * hand_ref_anim.alpha)
            UI.roundRect("fill", panel_x + 4, y - 1, panel_w - 8, line_h, 3)
            hovered_hand = hand
        end

        if round_hand and hand.name == round_hand.name then
            love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], hand_ref_anim.alpha)
        elseif is_hovered then
            love.graphics.setColor(1, 1, 1, hand_ref_anim.alpha)
        else
            love.graphics.setColor(UI.colors.text_dim[1], UI.colors.text_dim[2], UI.colors.text_dim[3], hand_ref_anim.alpha)
        end
        love.graphics.setFont(Fonts.get(font_size))
        love.graphics.print(hand.name, panel_x + 10, y)
        love.graphics.printf(hand:getDisplayScore(), panel_x, y, panel_w - 10, "right")
    end

    if hovered_hand then
        self:drawHandTooltip(hovered_hand, panel_x, panel_y, panel_w, mx, my)
    end
end

function Round:drawHandTooltip(hand, ref_x, ref_y, ref_w, mx, my)
    local example = hand_examples[hand.name]
    if not example then return end

    local die_size = 28
    local die_gap = 6
    local dice_row_w = #example * die_size + (#example - 1) * die_gap
    local pad = 12
    local tip_w = math.max(dice_row_w + pad * 2, 160)
    local tip_h = die_size + pad * 2 + 36

    local tip_x = ref_x - tip_w - 8
    local tip_y = math.max(ref_y, math.min(my - tip_h / 2, love.graphics.getHeight() - tip_h - 10))

    love.graphics.setColor(0.08, 0.08, 0.16, 0.95)
    UI.roundRect("fill", tip_x, tip_y, tip_w, tip_h, 8)
    UI.setColor(UI.colors.accent)
    love.graphics.setLineWidth(1.5)
    UI.roundRect("line", tip_x, tip_y, tip_w, tip_h, 8)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(Fonts.get(12))
    UI.setColor(UI.colors.accent)
    love.graphics.printf(hand.name, tip_x, tip_y + 8, tip_w, "center")

    local dice_x = tip_x + (tip_w - dice_row_w) / 2
    local dice_y = tip_y + 28

    for i, val in ipairs(example) do
        local ddx = dice_x + (i - 1) * (die_size + die_gap)
        UI.drawDie(ddx, dice_y, die_size, val, UI.colors.die_black)
    end
end

function Round:drawActions(player, W, H)
    if sub_state ~= "choosing" then return end

    local btn_w, btn_h = 180, 48
    local btn_y = H * 0.72
    local center_x = W / 2

    self:drawSortButtons(W, btn_y - 38)

    local has_locked = false
    for _, die in ipairs(player.dice_pool) do
        if die.locked then has_locked = true; break end
    end
    local score_pulse = has_locked and (0.9 + 0.1 * math.sin(love.timer.getTime() * 4)) or 1

    self._reroll_hovered = UI.drawButton(
        "REROLL (" .. player.rerolls_remaining .. ")",
        center_x - btn_w - 20, btn_y, btn_w, btn_h,
        {
            font = Fonts.get(20),
            disabled = player.rerolls_remaining <= 0,
            color = UI.colors.blue,
        }
    )

    love.graphics.push()
    local sc_cx = center_x + 20 + btn_w / 2
    local sc_cy = btn_y + btn_h / 2
    love.graphics.translate(sc_cx, sc_cy)
    love.graphics.scale(score_pulse, score_pulse)
    love.graphics.translate(-sc_cx, -sc_cy)
    self._score_hovered = UI.drawButton(
        "SCORE",
        center_x + 20, btn_y, btn_w, btn_h,
        { font = Fonts.get(20), color = UI.colors.green, hover_color = UI.colors.green_light }
    )
    love.graphics.pop()

    local kn = Settings.getKeyName
    local hint = kn(getKeybind("select_next")) .. " Select  |  " ..
        kn(getKeybind("move_left")) .. "/" .. kn(getKeybind("move_right")) .. " Move  |  " ..
        kn(getKeybind("toggle_lock")) .. " Lock  |  " ..
        kn(getKeybind("reroll")) .. " Reroll  |  " ..
        kn(getKeybind("score")) .. " Score  |  " ..
        kn(getKeybind("sort_cycle")) .. " Sort  |  " ..
        kn(getKeybind("show_tooltip")) .. " Info"

    love.graphics.setFont(Fonts.get(13))
    UI.setColor(UI.colors.text_dark)
    love.graphics.printf(hint, 0, btn_y + btn_h + 12, W, "center")
end

function Round:drawSortButtons(W, sort_y)
    local current_sort = Settings.get("dice_sort_mode") or "default"
    local sort_font = Fonts.get(12)
    local sort_btn_h = 26
    local sort_btn_gap = 5
    local mx, my = love.mouse.getPosition()

    local btn_widths = {}
    local total_w = 0
    for i, mode in ipairs(sort_modes) do
        local w = sort_font:getWidth(mode.label) + 18
        btn_widths[i] = w
        total_w = total_w + w
    end
    total_w = total_w + (#sort_modes - 1) * sort_btn_gap

    local label_font = Fonts.get(11)
    local label_text = "Sort:"
    local label_w = label_font:getWidth(label_text) + 8
    local full_w = label_w + total_w
    local start_x = (W - full_w) / 2

    love.graphics.setFont(label_font)
    UI.setColor(UI.colors.text_dark)
    love.graphics.print(label_text, start_x, sort_y + (sort_btn_h - label_font:getHeight()) / 2)

    self._sort_buttons = {}
    local sx = start_x + label_w
    for i, mode in ipairs(sort_modes) do
        local w = btn_widths[i]
        local is_active = mode.key == current_sort
        local hovered = UI.pointInRect(mx, my, sx, sort_y, w, sort_btn_h)

        if is_active then
            UI.setColor(UI.colors.accent)
        elseif hovered then
            UI.setColor(UI.colors.panel_hover)
        else
            UI.setColor(UI.colors.panel_light)
        end
        UI.roundRect("fill", sx, sort_y, w, sort_btn_h, 4)

        love.graphics.setFont(sort_font)
        if is_active then
            love.graphics.setColor(0.06, 0.06, 0.12, 1)
        elseif hovered then
            UI.setColor(UI.colors.text)
        else
            UI.setColor(UI.colors.text_dim)
        end
        love.graphics.printf(mode.label, sx, sort_y + (sort_btn_h - sort_font:getHeight()) / 2, w, "center")

        self._sort_buttons[i] = { x = sx, y = sort_y, w = w, h = sort_btn_h, hovered = hovered, mode_key = mode.key }
        sx = sx + w + sort_btn_gap
    end
end

function Round:drawPreRoll(player, W, H)
    local progress = 1 - math.max(0, pre_roll_timer / 1.2)
    local overlay_alpha = 1 - progress * progress
    love.graphics.setColor(0.04, 0.04, 0.08, overlay_alpha * 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.push()
    love.graphics.translate(W / 2, H * 0.38)
    love.graphics.scale(pre_roll_anim.scale, pre_roll_anim.scale)

    love.graphics.setFont(Fonts.get(48))
    love.graphics.setColor(1, 1, 1, pre_roll_anim.alpha)
    love.graphics.printf("Round " .. player.round, -W / 2, -24, W, "center")
    love.graphics.pop()

    love.graphics.setFont(Fonts.get(24))
    love.graphics.setColor(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], pre_roll_anim.alpha)
    love.graphics.printf("Target: " .. pre_roll_anim.target_count, 0, H * 0.38 + 40, W, "center")

    if player:isBossRound() then
        local boss_flash = 0.7 + 0.3 * math.sin(love.timer.getTime() * 10)
        love.graphics.setColor(UI.colors.red[1], UI.colors.red[2], UI.colors.red[3], pre_roll_anim.alpha * boss_flash)
        love.graphics.setFont(Fonts.get(28))
        love.graphics.printf("BOSS ROUND!", 0, H * 0.38 + 76, W, "center")
    end
end

function Round:drawScoring(player, W, H)
    if score_display_timer < 0.3 then
        local fade = score_display_timer / 0.3
        love.graphics.setColor(0, 0, 0, fade * 0.5)
        love.graphics.rectangle("fill", 0, 0, W, H)
        return
    end

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local panel_w, panel_h = 420, 260
    local px = (W - panel_w) / 2
    local py = H * 0.18

    local panel_progress = math.min(1, (score_display_timer - 0.3) / 0.3)
    local ps = 0.85 + 0.15 * Tween.easing.outBack(panel_progress)

    love.graphics.push()
    love.graphics.translate(px + panel_w / 2, py + panel_h / 2)
    love.graphics.scale(ps, ps)
    love.graphics.translate(-(px + panel_w / 2), -(py + panel_h / 2))

    UI.drawPanel(px, py, panel_w, panel_h, { border = UI.colors.accent, border_width = 2 })

    love.graphics.setFont(Fonts.get(28))
    UI.setColor(UI.colors.accent)
    love.graphics.printf(round_hand and round_hand.name or "No Hand", px, py + 14, panel_w, "center")

    love.graphics.setFont(Fonts.get(14))
    UI.setColor(UI.colors.text_dim)
    local breakdown = "(" .. round_base_score .. " + " .. round_dice_sum .. ") x " .. string.format("%.1f", round_multiplier)
    if round_bonus > 0 then
        breakdown = breakdown .. " + " .. round_bonus .. " bonus"
    end
    if round_mult_bonus > 0 then
        breakdown = breakdown .. " x " .. string.format("%.1f", 1 + round_mult_bonus) .. " item mult"
    end
    love.graphics.printf(breakdown, px, py + 48, panel_w, "center")

    love.graphics.setFont(Fonts.get(42))
    local t = UI.clamp((score_display_timer - 0.6) / 1.0, 0, 1)
    local eased_t = Tween.easing.outCubic(t)
    local display_score = math.floor(UI.lerp(0, round_score, eased_t))
    UI.setColor(UI.colors.text)
    love.graphics.printf(tostring(display_score), px, py + 72, panel_w, "center")

    if t >= 1 and scoring_shake.intensity == 0 and score_display_timer < 2.0 then
        scoring_shake.intensity = math.min(8, round_score / 50)
        local target = player:getTargetScore()
        if round_score >= target then
            Particles.burst(W / 2, py + 100, UI.colors.accent, 30)
        end
    end

    love.graphics.setFont(Fonts.get(18))
    local target = player:getTargetScore()
    if round_score >= target then
        UI.setColor(UI.colors.green)
        love.graphics.printf("TARGET MET! +" .. currency_earned .. " currency", px, py + 132, panel_w, "center")
    else
        UI.setColor(UI.colors.red)
        love.graphics.printf("TARGET MISSED (" .. target .. " needed)", px, py + 132, panel_w, "center")
    end

    if #dice_ability_results > 0 then
        love.graphics.setFont(Fonts.get(13))
        UI.setColor(UI.colors.text_dim)
        local ability_text = table.concat(dice_ability_results, " | ")
        love.graphics.printf(ability_text, px + 10, py + 166, panel_w - 20, "center")
    end

    love.graphics.pop()

    if score_display_timer > 2.0 then
        if round_score >= target then
            self._continue_hovered = UI.drawButton(
                "CONTINUE", (W - 200) / 2, py + panel_h + 20, 200, 48,
                { font = Fonts.get(20), color = UI.colors.green }
            )
        else
            self._game_over_hovered = UI.drawButton(
                "GAME OVER", (W - 200) / 2, py + panel_h + 20, 200, 48,
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
        local ddx = start_x + (v - 1) * (die_size + gap)
        local hovered = UI.pointInRect(mx, my, ddx, die_y, die_size, die_size)
        UI.drawDie(ddx, die_y, die_size, v, UI.colors.die_black, nil, false, hovered, UI.colors.accent)
        self._wild_values[v] = { x = ddx, y = die_y, w = die_size, h = die_size }
    end

    love.graphics.setFont(Fonts.get(13))
    UI.setColor(UI.colors.text_dark)
    love.graphics.printf("Press 1-6 to select  |  Esc to cancel", px, py + panel_h - 30, panel_w, "center")
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

local function doLockDie(self, player, idx)
    local die = player.dice_pool[idx]
    if not die then return end
    if boss_context and boss_context.boss_locked_die == die then
        Toast.error("Boss locked this die!")
        return
    end

    if die.die_type == "wild" and not die.locked then
        wild_selecting = true
        wild_die_index = idx
        return
    end

    player:lockDie(idx)
    local da = die_anims[idx]
    if da then
        da.pop_scale = 1.15
        da.lock_flash = 1.0
    end
    self:updatePreview(player)
    if Tutorial:isActive() then Tutorial:notifyAction("lock") end
end

local function doReroll(player)
    if player.rerolls_remaining <= 0 then return false end
    player:rerollUnlocked()
    sub_state = "rerolling"
    if Tutorial:isActive() then Tutorial:notifyAction("reroll") end
    return true
end

local function doScore(self, player)
    local score = self:calculateScore(player)
    sub_state = "scoring"
    score_display_timer = 0
    score_panel_anim = { alpha = 0, scale = 0.8 }
    selected_die_index = nil
    if score >= player:getTargetScore() then
        currency_earned = player:earnCurrency()
        local earn_context = { player = player, phase = "earn" }
        player:applyItems(earn_context)
    end
    if Tutorial:isActive() then Tutorial:notifyAction("score") end
end

local function cycleSortMode(self, player)
    local current = Settings.get("dice_sort_mode") or "default"
    local next_mode = sort_modes[1].key
    for i, mode in ipairs(sort_modes) do
        if mode.key == current then
            next_mode = sort_modes[(i % #sort_modes) + 1].key
            break
        end
    end
    Settings.set("dice_sort_mode", next_mode)
    Settings.save()
    self:applySortMode(player)
    self:updatePreview(player)
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
        local count = #player.dice_pool
        local layout = getDiceLayout(count, W, H)

        for i, die in ipairs(player.dice_pool) do
            local dx, dy = getDiePosition(layout, i, count)
            if UI.pointInRect(x, y, dx, dy, layout.die_size, layout.die_size) then
                selected_die_index = i
                doLockDie(self, player, i)
                return nil
            end
        end

        for _, btn in ipairs(self._sort_buttons or {}) do
            if btn.hovered then
                Settings.set("dice_sort_mode", btn.mode_key)
                Settings.save()
                self:applySortMode(player)
                self:updatePreview(player)
                return nil
            end
        end

        if self._reroll_hovered and player.rerolls_remaining > 0 then
            doReroll(player)
            return nil
        end

        if self._score_hovered then
            doScore(self, player)
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
    if wild_selecting then
        if key == "escape" then
            wild_selecting = false
            wild_die_index = nil
            return "handled"
        end
        local v = tonumber(key)
        if v and v >= 1 and v <= 6 then
            player.dice_pool[wild_die_index].value = v
            player.dice_pool[wild_die_index].wild_choice = v
            wild_selecting = false
            wild_die_index = nil
            self:updatePreview(player)
            return "handled"
        end
        return nil
    end

    if sub_state == "choosing" then
        local count = #player.dice_pool
        local shift_held = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

        if isKey(key, "select_next") and shift_held then
            if not selected_die_index then
                selected_die_index = count
            elseif selected_die_index > 1 then
                selected_die_index = selected_die_index - 1
            else
                selected_die_index = count
            end
        elseif isKey(key, "select_next") then
            if not selected_die_index then
                selected_die_index = 1
            else
                selected_die_index = (selected_die_index % count) + 1
            end
        elseif isKey(key, "show_tooltip") then
            tooltip_visible = not tooltip_visible
        elseif isKey(key, "move_left") then
            if not selected_die_index then
                selected_die_index = count
            elseif selected_die_index > 1 then
                selected_die_index = selected_die_index - 1
            else
                selected_die_index = count
            end
        elseif isKey(key, "move_right") then
            if not selected_die_index then
                selected_die_index = 1
            elseif selected_die_index < count then
                selected_die_index = selected_die_index + 1
            else
                selected_die_index = 1
            end
        elseif isKey(key, "toggle_lock") then
            if selected_die_index and selected_die_index >= 1 and selected_die_index <= count then
                doLockDie(self, player, selected_die_index)
            end
        elseif isKey(key, "reroll") then
            doReroll(player)
        elseif isKey(key, "score") then
            doScore(self, player)
        elseif isKey(key, "sort_cycle") then
            cycleSortMode(self, player)
        elseif tonumber(key) then
            local idx = tonumber(key)
            if idx == 0 then idx = 10 end
            if idx >= 1 and idx <= count then
                selected_die_index = idx
                doLockDie(self, player, idx)
            end
        end
    elseif sub_state == "scoring" and score_display_timer > 2.0 then
        if key == "return" or key == "space" or isKey(key, "score") then
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

function Round:setBossContext(ctx)
    boss_context = ctx
end

return Round
