local SaveLoad = require("functions/saveload")

_G.game_save_hook = nil

function love.focus(f)
    if not f then
        if _G.game_save_hook then
            _G.game_save_hook()
        end
    end
end

function love.quit()
    if _G.game_save_hook then
        _G.game_save_hook()
    end
    print("Thanks for playing! Come back soon!")
end
