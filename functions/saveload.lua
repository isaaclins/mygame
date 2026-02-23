local SaveLoad = {}

local SAVE_FILE = "savedata.lua"

local function serialize(val, indent)
    indent = indent or 0
    local pad = string.rep("  ", indent)
    local t = type(val)

    if t == "number" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "boolean" then
        return tostring(val)
    elseif t == "nil" then
        return "nil"
    elseif t == "table" then
        local parts = {}
        local pad2 = string.rep("  ", indent + 1)

        local is_array = true
        local max_i = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_array = false
                break
            end
            if k > max_i then max_i = k end
        end
        if is_array and max_i == #val then
            for i, v in ipairs(val) do
                table.insert(parts, pad2 .. serialize(v, indent + 1))
            end
        else
            is_array = false
            for k, v in pairs(val) do
                if type(k) == "string" then
                    table.insert(parts, pad2 .. "[" .. string.format("%q", k) .. "] = " .. serialize(v, indent + 1))
                elseif type(k) == "number" then
                    table.insert(parts, pad2 .. "[" .. k .. "] = " .. serialize(v, indent + 1))
                end
            end
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. pad .. "}"
    end
    return "nil"
end

function SaveLoad.serializeDie(die)
    local data = {
        name = die.name,
        color = die.color,
        die_type = die.die_type,
        value = die.value,
        ability_name = die.ability_name,
        ability_desc = die.ability_desc,
        upgrade_level = die.upgrade_level,
        weights = {},
    }
    for i, w in ipairs(die.weights) do
        data.weights[i] = w
    end
    if die.glow_color then
        data.glow_color = { die.glow_color[1], die.glow_color[2], die.glow_color[3], die.glow_color[4] }
    end
    if die._sort_order then
        data._sort_order = die._sort_order
    end
    return data
end

function SaveLoad.serializeHand(hand)
    return {
        name = hand.name,
        base_score = hand.base_score,
        multiplier = hand.multiplier,
        upgrade_level = hand.upgrade_level,
    }
end

function SaveLoad.buildSaveData(game_state, player, rng_state)
    if not player then return nil end
    local data = {
        version = 1,
        state = game_state,
        seed = player.seed or "",
        rng_state = rng_state or "",
        round = player.round,
        currency = player.currency,
        base_rerolls = player.base_rerolls,
        dice_pool = {},
        hands = {},
        item_names = {},
    }

    for _, die in ipairs(player.dice_pool) do
        table.insert(data.dice_pool, SaveLoad.serializeDie(die))
    end

    for _, hand in ipairs(player.hands) do
        table.insert(data.hands, SaveLoad.serializeHand(hand))
    end

    for _, item in ipairs(player.items) do
        table.insert(data.item_names, item.name)
    end

    return data
end

function SaveLoad.save(game_state, player, rng_state)
    local data = SaveLoad.buildSaveData(game_state, player, rng_state)
    if not data then return false end

    local content = "return " .. serialize(data, 0) .. "\n"
    local ok, err = love.filesystem.write(SAVE_FILE, content)
    if ok then
        print("[save] Game saved successfully")
    else
        print("[save] Failed to save: " .. tostring(err))
    end
    return ok
end

function SaveLoad.hasSave()
    return love.filesystem.getInfo(SAVE_FILE) ~= nil
end

function SaveLoad.load()
    if not SaveLoad.hasSave() then return nil end

    local chunk, err = love.filesystem.load(SAVE_FILE)
    if not chunk then
        print("[load] Failed to load save: " .. tostring(err))
        return nil
    end

    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then
        print("[load] Corrupt save data")
        return nil
    end

    if data.version ~= 1 then
        print("[load] Incompatible save version")
        return nil
    end

    return data
end

function SaveLoad.deleteSave()
    if SaveLoad.hasSave() then
        love.filesystem.remove(SAVE_FILE)
        print("[save] Save deleted")
    end
end

function SaveLoad.restorePlayer(data, Player, Die, createDiceTypes, createItems, createHands)
    local player = Player:new()
    player.round = data.round or 1
    player.currency = data.currency or 0
    player.base_rerolls = data.base_rerolls or 3

    local templates = {}
    for _, dt in ipairs(createDiceTypes()) do
        templates[dt.die_type] = dt
    end

    player.dice_pool = {}
    for _, dd in ipairs(data.dice_pool or {}) do
        local template = templates[dd.die_type]
        local die = Die:new({
            name = dd.name,
            color = dd.color,
            die_type = dd.die_type,
            value = dd.value,
            ability_name = dd.ability_name,
            ability_desc = dd.ability_desc,
            upgrade_level = dd.upgrade_level or 0,
            weights = dd.weights,
            glow_color = dd.glow_color,
        })
        if template and template.ability then
            die.ability = template.ability
        end
        die._sort_order = dd._sort_order or i
        table.insert(player.dice_pool, die)
    end

    local base_hands = createHands()
    player.hands = {}
    local saved_hands = data.hands or {}

    local saved_by_name = {}
    for _, hd in ipairs(saved_hands) do
        if hd.name then saved_by_name[hd.name] = hd end
    end

    local old_xoak_names = {
        "Three of a Kind", "Four of a Kind",
        "Five of a Kind", "Six of a Kind", "Seven of a Kind",
    }
    local merged_xoak_level = 0
    for _, old_name in ipairs(old_xoak_names) do
        local hd = saved_by_name[old_name]
        if hd and (hd.upgrade_level or 0) > merged_xoak_level then
            merged_xoak_level = hd.upgrade_level
        end
    end

    for _, hand in ipairs(base_hands) do
        local hd = saved_by_name[hand.name]
        if hd then
            local lvl = hd.upgrade_level or 0
            if lvl > 0 then hand:setUpgradeLevel(lvl) end
        elseif hand.is_x_of_a_kind and merged_xoak_level > 0 then
            hand:setUpgradeLevel(merged_xoak_level)
        end
        table.insert(player.hands, hand)
    end

    local all_items = createItems()
    local item_lookup = {}
    for _, item in ipairs(all_items) do
        item_lookup[item.name] = item
    end
    player.items = {}
    for _, name in ipairs(data.item_names or {}) do
        local item = item_lookup[name]
        if item then
            table.insert(player.items, item)
        end
    end

    return player
end

return SaveLoad
