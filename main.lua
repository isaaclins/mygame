local Player = require("objects/player")
local Die = require("objects/die")
local createHands = require("content/hands")
local createDiceTypes = require("content/dice_types")
local createItems = require("content/items")
local createBosses = require("content/bosses")
local SaveLoad = require("functions/saveload")
local RNG = require("functions/rng")

local Splash = require("states/splash")
local SeedInput = require("states/seed_input")
local RoundState = require("states/round")
local ShopState = require("states/shop_state")
local GameOverState = require("states/game_over")
local PauseState = require("states/pause")

local state = "splash"
local paused = false
local player = nil
local all_dice_types = nil
local all_items = nil
local all_bosses = nil
local current_boss = nil
local current_seed = ""

local function saveGame()
    if player and (state == "round" or state == "shop") then
        SaveLoad.save(state, player, RNG.getState())
    end
end

local function initNewGame(seed)
    SaveLoad.deleteSave()

    current_seed = seed
    RNG.setSeed(seed)

    player = Player:new()
    player.seed = seed
    all_dice_types = createDiceTypes()
    all_items = createItems()
    all_bosses = createBosses()

    player.hands = createHands()

    for i = 1, 5 do
        table.insert(player.dice_pool, Die:new({
            name = "Vanilla Die",
            color = "black",
            die_type = "vanilla",
            ability_name = "None",
            ability_desc = "A standard die.",
        }))
    end

    current_boss = nil
    paused = false
    state = "round"
    RoundState:init(player, nil)
end

local function loadGame()
    local data = SaveLoad.load()
    if not data then return false end

    current_seed = data.seed or "UNKNOWN"
    RNG.setSeed(current_seed)
    if data.rng_state then
        RNG.setState(data.rng_state)
    end

    all_dice_types = createDiceTypes()
    all_items = createItems()
    all_bosses = createBosses()

    player = SaveLoad.restorePlayer(data, Player, Die, createDiceTypes, createItems, createHands)
    player.seed = current_seed
    current_boss = nil
    paused = false

    if data.state == "shop" then
        state = "shop"
        ShopState:init(player, all_dice_types, all_items)
    else
        state = "round"
        if player:isBossRound() then
            current_boss = all_bosses[RNG.random(1, #all_bosses)]
        end
        RoundState:init(player, current_boss)
    end

    return true
end

local function startRound()
    current_boss = nil
    if player:isBossRound() then
        current_boss = all_bosses[RNG.random(1, #all_bosses)]
    end
    RoundState:init(player, current_boss)
end

function love.load()
    love.graphics.setBackgroundColor(0.06, 0.06, 0.12)

    local default_font = love.graphics.newFont(16)
    love.graphics.setFont(default_font)

    love.window.setIcon(love.image.newImageData("content/icon/icon.png"))
    love.window.setTitle("Dice × Balatro")
    love.window.setMode(1280, 720, {
        highdpi = true,
        resizable = true,
        minwidth = 960,
        minheight = 540,
    })

    _G.game_save_hook = saveGame
    require("functions/window")

    Splash:init()
end

function love.update(dt)
    if paused then return end

    if state == "splash" then
        Splash:update(dt)
    elseif state == "seed_input" then
        SeedInput:update(dt)
    elseif state == "round" then
        RoundState:update(dt, player)
    elseif state == "shop" then
        ShopState:update(dt)
    elseif state == "game_over" then
        GameOverState:update(dt)
    end
end

function love.draw()
    if state == "splash" then
        Splash:draw()
    elseif state == "seed_input" then
        SeedInput:draw()
    elseif state == "round" then
        RoundState:draw(player, current_boss)
    elseif state == "shop" then
        ShopState:draw(player)
    elseif state == "game_over" then
        GameOverState:draw(player)
    end

    if paused then
        PauseState:draw()
    end
end

function love.mousepressed(x, y, button)
    if paused then
        local result = PauseState:mousepressed(x, y, button)
        handlePauseResult(result)
        return
    end

    local result = nil

    if state == "splash" then
        result = Splash:mousepressed(x, y, button)
    elseif state == "seed_input" then
        result = SeedInput:mousepressed(x, y, button)
    elseif state == "round" then
        result = RoundState:mousepressed(x, y, button, player)
    elseif state == "shop" then
        result = ShopState:mousepressed(x, y, button, player)
    elseif state == "game_over" then
        result = GameOverState:mousepressed(x, y, button)
    end

    handleResult(result)
end

function love.keypressed(key)
    if paused then
        local result = PauseState:keypressed(key)
        handlePauseResult(result)
        return
    end

    local result = nil

    if state == "splash" then
        result = Splash:keypressed(key)
    elseif state == "seed_input" then
        result = SeedInput:keypressed(key)
    elseif state == "round" then
        result = RoundState:keypressed(key, player)
    elseif state == "shop" then
        result = ShopState:keypressed(key)
    elseif state == "game_over" then
        result = GameOverState:keypressed(key)
    end

    if result then
        handleResult(result)
        return
    end

    if key == "escape" and (state == "round" or state == "shop") then
        paused = true
        return
    end
end

function love.textinput(text)
    if state == "seed_input" then
        SeedInput:textinput(text)
    end
end

function handlePauseResult(result)
    if not result then return end

    if result == "resume" then
        paused = false
    elseif result == "save_and_menu" then
        saveGame()
        paused = false
        state = "splash"
        Splash:init()
    elseif result == "save_and_exit" then
        saveGame()
        love.event.quit()
    end
end

function handleResult(result)
    if not result then return end

    if result == "start_game" then
        state = "seed_input"
        SeedInput:init()
    elseif result == "confirm_seed" then
        local seed = SeedInput:getSeed()
        initNewGame(seed)
    elseif result == "back_to_menu" then
        state = "splash"
        Splash:init()
    elseif result == "continue_game" then
        if not loadGame() then
            state = "seed_input"
            SeedInput:init()
        end
    elseif result == "exit" then
        love.event.quit()
    elseif result == "to_shop" then
        local boss_ctx = RoundState:getBossContext()
        if current_boss and boss_ctx then
            current_boss:revertModifier(boss_ctx)
        end
        state = "shop"
        ShopState:init(player, all_dice_types, all_items)
        saveGame()
    elseif result == "next_round" then
        player.round = player.round + 1
        state = "round"
        startRound()
        saveGame()
    elseif result == "game_over" then
        local boss_ctx = RoundState:getBossContext()
        if current_boss and boss_ctx then
            current_boss:revertModifier(boss_ctx)
        end
        SaveLoad.deleteSave()
        state = "game_over"
        GameOverState:init()
    elseif result == "restart" then
        state = "splash"
        Splash:init()
    end
end
