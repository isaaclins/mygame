local Player = require("objects/player")
local Die = require("objects/die")
local createHands = require("content/hands")
local createDiceTypes = require("content/dice_types")
local createItems = require("content/items")
local createBosses = require("content/bosses")
local SaveLoad = require("functions/saveload")
local RNG = require("functions/rng")
local Settings = require("functions/settings")
local Tween = require("functions/tween")
local Particles = require("functions/particles")
local Transition = require("functions/transition")
local Toast = require("functions/toast")
local Fonts = require("functions/fonts")
local Updater = require("functions/updater")

local Splash = require("states/splash")
local SeedInput = require("states/seed_input")
local RoundState = require("states/round")
local ShopState = require("states/shop_state")
local GameOverState = require("states/game_over")
local PauseState = require("states/pause")
local SettingsState = require("states/settings")
local Tutorial = require("states/tutorial")
local DevMenu = require("states/devmenu")

local state = "splash"
local paused = false
local unfocused = false
local tutorial_active = false
local devmenu_open = false
local player = nil
local all_dice_types = nil
local all_items = nil
local all_bosses = nil
local current_boss = nil
local current_seed = ""
local music = nil

local function applyMusicVolume()
    if not music then return end
    local vol = Settings.get("music_volume") * Settings.get("master_volume")
    music:setVolume(vol)
end

local function applyMuffle()
    if not music then return end
    music:setFilter({ type = "lowpass", highgain = 0.03, volume = 0.45 })
end

local function clearMuffle()
    if not music then return end
    music:setFilter()
end

local function saveGame()
    if tutorial_active then return end
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
        local die = Die:new({
            name = "Normal Die",
            color = "black",
            die_type = "Normal",
            ability_name = "None",
            ability_desc = "A standard die.",
        })
        die._sort_order = i
        table.insert(player.dice_pool, die)
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

    Settings.load()

    love.window.setIcon(love.image.newImageData("content/icon/icon.png"))
    love.window.setTitle("Dice × Balatro")
    love.window.setMode(1280, 720, {
        highdpi = true,
        resizable = true,
        minwidth = 960,
        minheight = 540,
        vsync = Settings.get("vsync") and 1 or 0,
    })

    if Settings.get("fullscreen") then
        love.window.setFullscreen(true)
    end

    music = love.audio.newSource("content/sfx/music.mp3", "stream")
    music:setLooping(true)
    applyMusicVolume()
    music:play()

    _G.game_save_hook = saveGame
    require("functions/window")

    Updater.check()
    Splash:init()
end

function love.focus(f)
    if not f then
        unfocused = true
        if _G.game_save_hook then _G.game_save_hook() end
        if Settings.get("pause_on_unfocus") and music then
            music:pause()
        end
    else
        unfocused = false
        if music and not music:isPlaying() then
            music:play()
        end
    end
end

function love.quit()
    if _G.game_save_hook then _G.game_save_hook() end
    Settings.save()
    print("Thanks for playing! Come back soon!")
end

function love.update(dt)
    Transition.update(dt)
    Tween.update(dt)
    Particles.update(dt)
    Toast.update(dt)

    if Updater.update() then
        Toast.info("New version available: v" .. Updater.getLatestVersion())
    end

    if unfocused and Settings.get("pause_on_unfocus") then return end
    if paused and state ~= "settings" then return end

    applyMusicVolume()

    if state == "splash" then
        Splash:update(dt)
    elseif state == "seed_input" then
        SeedInput:update(dt)
    elseif state == "settings" then
        SettingsState:update(dt)
    elseif state == "round" then
        RoundState:update(dt, player)
    elseif state == "shop" then
        ShopState:update(dt)
    elseif state == "game_over" then
        GameOverState:update(dt)
    end

    if tutorial_active then
        Tutorial:update(dt)
        if Tutorial:isCompleted() then
            tutorial_active = false
            Transition.fadeTo(function()
                state = "splash"
                Splash:init()
            end, 0.25)
        end
    end
end

function love.draw()
    if state == "splash" then
        Splash:draw()
    elseif state == "seed_input" then
        SeedInput:draw()
    elseif state == "settings" then
        if SettingsState._from_state == "pause" then
            if SettingsState._game_draw == "round" then
                RoundState:draw(player, current_boss)
            elseif SettingsState._game_draw == "shop" then
                ShopState:draw(player)
            end
        end
        SettingsState:draw()
    elseif state == "round" then
        RoundState:draw(player, current_boss)
    elseif state == "shop" then
        ShopState:draw(player)
    elseif state == "game_over" then
        GameOverState:draw(player)
    end

    if state == "splash" and not devmenu_open then
        local W, H = love.graphics.getDimensions()
        DevMenu:drawButton(W, H)
    end

    if paused and state ~= "settings" then
        PauseState:draw()
    end

    if devmenu_open and state == "splash" then
        DevMenu:draw()
    end

    if tutorial_active then
        Tutorial:draw()
    end

    Particles.draw()
    Toast.draw()
    Transition.draw()

    if Settings.get("show_fps") then
        love.graphics.setFont(Fonts.get(14))
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 8, love.graphics.getHeight() - 22)
    end

    if unfocused and Settings.get("pause_on_unfocus") then
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    end
end

function love.mousepressed(x, y, button)
    if Transition.isActive() then return end
    if unfocused and Settings.get("pause_on_unfocus") then return end

    if tutorial_active then
        local consumed = Tutorial:mousepressed(x, y, button)
        if Tutorial:isCompleted() then return end
        if consumed then return end
        if Tutorial:shouldBlockInput() then return end
    end

    if state == "settings" then
        local result = SettingsState:mousepressed(x, y, button)
        handleResult(result)
        return
    end

    if devmenu_open and state == "splash" then
        local result = DevMenu:mousepressed(x, y, button)
        if result == "close" then
            devmenu_open = false
        elseif result == "start_debug" then
            devmenu_open = false
            handleResult("dev_start_game")
        end
        return
    end

    if state == "splash" and DevMenu:isButtonClicked(x, y) then
        devmenu_open = true
        DevMenu:open()
        return
    end

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

function love.mousereleased(x, y, button)
    if state == "settings" then
        SettingsState:mousereleased(x, y, button)
    end
end

function love.keypressed(key)
    if Transition.isActive() then return end
    if unfocused and Settings.get("pause_on_unfocus") then return end

    if tutorial_active then
        local consumed = Tutorial:keypressed(key)
        if Tutorial:isCompleted() then return end
        if consumed then return end
        if Tutorial:shouldBlockInput() then return end
    end

    if state == "settings" then
        local result = SettingsState:keypressed(key)
        handleResult(result)
        return
    end

    if devmenu_open and state == "splash" then
        local result = DevMenu:keypressed(key)
        if result == "close" then
            devmenu_open = false
        elseif result == "start_debug" then
            devmenu_open = false
            handleResult("dev_start_game")
        end
        return
    end

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
        result = ShopState:keypressed(key, player)
    elseif state == "game_over" then
        result = GameOverState:keypressed(key)
    end

    if result then
        handleResult(result)
        return
    end

    if key == "escape" and (state == "round" or state == "shop") and not tutorial_active then
        paused = true
        applyMuffle()
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
        clearMuffle()
    elseif result == "settings" then
        SettingsState._from_state = "pause"
        SettingsState._game_draw = state
        state = "settings"
        SettingsState:init({ from_pause = true })
    elseif result == "save_and_menu" then
        saveGame()
        paused = false
        clearMuffle()
        state = "splash"
        Splash:init()
    elseif result == "save_and_exit" then
        saveGame()
        love.event.quit()
    end
end

function handleResult(result)
    if not result then return end

    if result == "tutorial" then
        Transition.fadeTo(function()
            tutorial_active = true
            initNewGame("TUTORIAL")
            Tutorial:init()
        end, 0.25)
    elseif result == "start_game" then
        Transition.fadeTo(function()
            state = "seed_input"
            SeedInput:init()
        end, 0.2)
    elseif result == "confirm_seed" then
        local seed = SeedInput:getSeed()
        Transition.fadeTo(function() initNewGame(seed) end, 0.25)
    elseif result == "back_to_menu" then
        Transition.fadeTo(function()
            state = "splash"
            Splash:init()
        end, 0.2)
    elseif result == "continue_game" then
        Transition.fadeTo(function()
            if not loadGame() then
                state = "seed_input"
                SeedInput:init()
            end
        end, 0.25)
    elseif result == "open_settings" then
        SettingsState._from_state = "splash"
        SettingsState._game_draw = nil
        state = "settings"
        SettingsState:init({ from_pause = false })
    elseif result == "settings_back" then
        applyMusicVolume()
        love.window.setVSync(Settings.get("vsync") and 1 or 0)
        love.window.setFullscreen(Settings.get("fullscreen") or false)
        if SettingsState._from_state == "pause" then
            state = SettingsState._game_draw or "round"
            paused = true
        else
            state = "splash"
            Splash:init()
        end
    elseif result == "dev_start_game" then
        Transition.fadeTo(function()
            SaveLoad.deleteSave()
            local seed = "DEBUG"
            current_seed = seed
            RNG.setSeed(seed)

            local draft = DevMenu:getDraft()
            player = draft
            player.seed = seed
            all_dice_types = createDiceTypes()
            all_items = createItems()
            all_bosses = createBosses()

            current_boss = DevMenu:getSelectedBoss()
            paused = false
            state = "round"
            RoundState:init(player, current_boss)
        end, 0.25)
    elseif result == "exit" then
        love.event.quit()
    elseif result == "to_shop" then
        Transition.fadeTo(function()
            local boss_ctx = RoundState:getBossContext()
            if current_boss and boss_ctx then
                current_boss:revertModifier(boss_ctx)
            end
            state = "shop"
            ShopState:init(player, all_dice_types, all_items)
            saveGame()
            if tutorial_active then
                Tutorial:notifyStateChange("shop")
            end
        end, 0.25)
    elseif result == "next_round" then
        if tutorial_active then
            Tutorial:notifyAction("continue")
            return
        end
        Transition.fadeTo(function()
            player.round = player.round + 1
            state = "round"
            startRound()
            saveGame()
        end, 0.25)
    elseif result == "game_over" then
        Transition.fadeTo(function()
            local boss_ctx = RoundState:getBossContext()
            if current_boss and boss_ctx then
                current_boss:revertModifier(boss_ctx)
            end
            SaveLoad.deleteSave()
            state = "game_over"
            GameOverState:init()
        end, 0.35)
    elseif result == "restart" then
        Transition.fadeTo(function()
            state = "splash"
            Splash:init()
        end, 0.25)
    end
end
