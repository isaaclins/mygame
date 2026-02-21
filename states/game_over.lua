local UI = require("functions/ui")
local Fonts = require("functions/fonts")

local GameOver = {}

local time_elapsed = 0

function GameOver:init()
    time_elapsed = 0
end

function GameOver:update(dt)
    time_elapsed = time_elapsed + dt
end

function GameOver:draw(player)
    local W, H = love.graphics.getDimensions()

    UI.setColor(UI.colors.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(0.9, 0.15, 0.15, 0.08)
    for i = 1, 8 do
        local r = 50 + i * 40 + math.sin(time_elapsed + i) * 20
        love.graphics.circle("fill", W / 2, H * 0.35, r)
    end

    love.graphics.setFont(Fonts.get(52))
    UI.setColor(UI.colors.red)
    love.graphics.printf("GAME OVER", 0, H * 0.18, W, "center")

    love.graphics.setFont(Fonts.get(22))
    UI.setColor(UI.colors.text)

    local stats_y = H * 0.38
    love.graphics.printf("Round Reached: " .. player.round, 0, stats_y, W, "center")
    love.graphics.printf("Final Currency: $" .. player.currency, 0, stats_y + 36, W, "center")
    love.graphics.printf("Dice Pool:", 0, stats_y + 72, W, "center")

    local die_names = {}
    for _, die in ipairs(player.dice_pool) do
        table.insert(die_names, die.name)
    end
    love.graphics.setFont(Fonts.get(18))
    UI.setColor(UI.colors.text_dim)
    love.graphics.printf(table.concat(die_names, ", "), W * 0.15, stats_y + 100, W * 0.7, "center")

    if #player.items > 0 then
        local item_names = {}
        for _, item in ipairs(player.items) do
            table.insert(item_names, item.name)
        end
        love.graphics.printf("Items: " .. table.concat(item_names, ", "), W * 0.15, stats_y + 130, W * 0.7, "center")
    end

    if player.seed and #player.seed > 0 then
        love.graphics.setFont(Fonts.get(16))
        UI.setColor(UI.colors.accent_dim)
        love.graphics.printf("Seed: " .. player.seed, 0, stats_y + 160, W, "center")
    end

    local btn_w, btn_h = 260, 56
    self._retry_hovered = UI.drawButton(
        "PLAY AGAIN", (W - btn_w) / 2, H * 0.75, btn_w, btn_h,
        { font = Fonts.get(24), color = UI.colors.blue }
    )

    self._exit_hovered = UI.drawButton(
        "EXIT", (W - btn_w) / 2, H * 0.75 + 70, btn_w, btn_h,
        { font = Fonts.get(24), color = UI.colors.red, hover_color = { 0.95, 0.30, 0.30, 1 } }
    )
end

function GameOver:mousepressed(x, y, button)
    if button ~= 1 then return nil end

    if self._retry_hovered then
        return "restart"
    elseif self._exit_hovered then
        return "exit"
    end
    return nil
end

function GameOver:keypressed(key)
    if key == "return" or key == "space" then
        return "restart"
    elseif key == "escape" then
        return "exit"
    end
    return nil
end

return GameOver
