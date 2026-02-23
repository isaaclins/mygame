local Scoring = {}

function Scoring.getCounts(values)
    local counts = {}
    for _, v in ipairs(values) do
        counts[v] = (counts[v] or 0) + 1
    end
    return counts
end

local function countsKey(c)
    return (c[1] or 0) .. "," .. (c[2] or 0) .. "," .. (c[3] or 0) .. ","
        .. (c[4] or 0) .. "," .. (c[5] or 0) .. "," .. (c[6] or 0)
end

local function totalDice(c)
    local t = 0
    for _, v in pairs(c) do t = t + v end
    return t
end

local function subtractMatched(c, matched)
    local new = {}
    for k, v in pairs(c) do new[k] = v end
    for _, v in ipairs(matched) do
        new[v] = (new[v] or 0) - 1
        if new[v] <= 0 then new[v] = nil end
    end
    return new
end

local function generateExtractions(c, hand_lookup)
    local extractions = {}
    local n = totalDice(c)

    local xoak = hand_lookup["X of a Kind"]

    -- X of a Kind (x >= 3)
    if xoak then
        for v = 1, 6 do
            local cv = c[v] or 0
            if cv >= 3 then
                for x = 3, cv do
                    local matched = {}
                    for _ = 1, x do matched[#matched + 1] = v end
                    local score = xoak:calculateXOfAKindScore(x, matched)
                    extractions[#extractions + 1] = { hand = xoak, matched = matched, score = score }
                end
            end
        end
    end

    -- Pair
    local pair_hand = hand_lookup["Pair"]
    local pair_vals = {}
    if pair_hand then
        for v = 1, 6 do
            if (c[v] or 0) >= 2 then
                pair_vals[#pair_vals + 1] = v
                local matched = { v, v }
                local score = pair_hand:calculateScore(nil, matched)
                extractions[#extractions + 1] = { hand = pair_hand, matched = matched, score = score }
            end
        end
    end

    -- Two Pair
    local tp_hand = hand_lookup["Two Pair"]
    if tp_hand and #pair_vals >= 2 then
        for i = 1, #pair_vals do
            for j = i + 1, #pair_vals do
                local a, b = pair_vals[i], pair_vals[j]
                local matched = { a, a, b, b }
                local score = tp_hand:calculateScore(nil, matched)
                extractions[#extractions + 1] = { hand = tp_hand, matched = matched, score = score }
            end
        end
    end

    -- Full House (3 of one + 2 of another) — combo of X-of-a-Kind + Pair with bonus
    local fh_hand = hand_lookup["Full House"]
    if fh_hand and xoak and pair_hand then
        for v1 = 1, 6 do
            if (c[v1] or 0) >= 3 then
                for v2 = 1, 6 do
                    if v2 ~= v1 and (c[v2] or 0) >= 2 then
                        local matched = { v1, v1, v1, v2, v2 }
                        local triple_score = xoak:calculateXOfAKindScore(3, { v1, v1, v1 })
                        local pair_score = pair_hand:calculateScore(nil, { v2, v2 })
                        local score = triple_score + pair_score + fh_hand.base_score
                        extractions[#extractions + 1] = { hand = fh_hand, matched = matched, score = score }
                    end
                end
            end
        end
    end

    -- Small Straight (4 consecutive)
    local ss_hand = hand_lookup["Small Straight"]
    if ss_hand then
        for start = 1, 3 do
            local ok = true
            for v = start, start + 3 do
                if (c[v] or 0) < 1 then ok = false; break end
            end
            if ok then
                local matched = {}
                for v = start, start + 3 do matched[#matched + 1] = v end
                local score = ss_hand:calculateScore(nil, matched)
                extractions[#extractions + 1] = { hand = ss_hand, matched = matched, score = score }
            end
        end
    end

    -- Large Straight (5 consecutive)
    local ls_hand = hand_lookup["Large Straight"]
    if ls_hand then
        for start = 1, 2 do
            local ok = true
            for v = start, start + 4 do
                if (c[v] or 0) < 1 then ok = false; break end
            end
            if ok then
                local matched = {}
                for v = start, start + 4 do matched[#matched + 1] = v end
                local score = ls_hand:calculateScore(nil, matched)
                extractions[#extractions + 1] = { hand = ls_hand, matched = matched, score = score }
            end
        end
    end

    -- Full Run (1-6 all present, 6+ dice)
    local fr_hand = hand_lookup["Full Run"]
    if fr_hand and n >= 6 then
        local ok = true
        for v = 1, 6 do
            if (c[v] or 0) < 1 then ok = false; break end
        end
        if ok then
            local matched = { 1, 2, 3, 4, 5, 6 }
            local score = fr_hand:calculateScore(nil, matched)
            extractions[#extractions + 1] = { hand = fr_hand, matched = matched, score = score }
        end
    end

    -- Three Pairs (3 different pairs, 6+ dice)
    local threep_hand = hand_lookup["Three Pairs"]
    if threep_hand and #pair_vals >= 3 then
        for i = 1, #pair_vals do
            for j = i + 1, #pair_vals do
                for k = j + 1, #pair_vals do
                    local a, b, d = pair_vals[i], pair_vals[j], pair_vals[k]
                    local matched = { a, a, b, b, d, d }
                    local score = threep_hand:calculateScore(nil, matched)
                    extractions[#extractions + 1] = { hand = threep_hand, matched = matched, score = score }
                end
            end
        end
    end

    -- Two Triplets (2 sets of 3, 6+ dice)
    local tt_hand = hand_lookup["Two Triplets"]
    if tt_hand then
        local triple_vals = {}
        for v = 1, 6 do
            if (c[v] or 0) >= 3 then triple_vals[#triple_vals + 1] = v end
        end
        for i = 1, #triple_vals do
            for j = i + 1, #triple_vals do
                local a, b = triple_vals[i], triple_vals[j]
                local matched = { a, a, a, b, b, b }
                local score = tt_hand:calculateScore(nil, matched)
                extractions[#extractions + 1] = { hand = tt_hand, matched = matched, score = score }
            end
        end
    end

    -- Pyramid (1x2, 3x4, 5x6)
    local pyr_hand = hand_lookup["Pyramid"]
    if pyr_hand and (c[2] or 0) >= 1 and (c[4] or 0) >= 3 and (c[6] or 0) >= 5 then
        local matched = { 2, 4, 4, 4, 6, 6, 6, 6, 6 }
        local score = pyr_hand:calculateScore(nil, matched)
        extractions[#extractions + 1] = { hand = pyr_hand, matched = matched, score = score }
    end

    -- All Even (every die even, 5+ dice; uses ALL remaining dice)
    local ae_hand = hand_lookup["All Even"]
    if ae_hand and n >= 5 and (c[1] or 0) == 0 and (c[3] or 0) == 0 and (c[5] or 0) == 0 then
        local matched = {}
        for v = 2, 6, 2 do
            for _ = 1, (c[v] or 0) do matched[#matched + 1] = v end
        end
        local score = ae_hand:calculateScore(nil, matched)
        extractions[#extractions + 1] = { hand = ae_hand, matched = matched, score = score }
    end

    -- All Odd (every die odd, 5+ dice; uses ALL remaining dice)
    local ao_hand = hand_lookup["All Odd"]
    if ao_hand and n >= 5 and (c[2] or 0) == 0 and (c[4] or 0) == 0 and (c[6] or 0) == 0 then
        local matched = {}
        for v = 1, 5, 2 do
            for _ = 1, (c[v] or 0) do matched[#matched + 1] = v end
        end
        local score = ao_hand:calculateScore(nil, matched)
        extractions[#extractions + 1] = { hand = ao_hand, matched = matched, score = score }
    end

    return extractions
end

function Scoring.findOptimalCombination(values, hands_list)
    local counts = Scoring.getCounts(values)

    local hand_lookup = {}
    for _, hand in ipairs(hands_list) do
        hand_lookup[hand.name] = hand
    end

    local memo = {}

    local function solve(c)
        local key = countsKey(c)
        if memo[key] then return memo[key] end

        local extractions = generateExtractions(c, hand_lookup)

        local best_score = 0
        local best_combo = {}

        for _, ext in ipairs(extractions) do
            local remaining = subtractMatched(c, ext.matched)
            local sub = solve(remaining)
            local total = ext.score + sub.score

            if total > best_score then
                best_score = total
                best_combo = { { hand = ext.hand, matched = ext.matched, score = ext.score } }
                for _, entry in ipairs(sub.combo) do
                    best_combo[#best_combo + 1] = entry
                end
            end
        end

        local result = { score = best_score, combo = best_combo }
        memo[key] = result
        return result
    end

    local result = solve(counts)

    if #result.combo == 0 then
        local high_hand = hand_lookup["High Roll"]
        if high_hand and #values > 0 then
            local high = values[1]
            for _, v in ipairs(values) do
                if v > high then high = v end
            end
            local score = high_hand:calculateScore(nil, { high })
            return { { hand = high_hand, matched = { high }, score = score } }, score
        end
        return {}, 0
    end

    return result.combo, result.score
end

function Scoring.comboEntryName(entry)
    if entry.hand.is_x_of_a_kind then
        local x = #entry.matched
        local val = entry.matched[1]
        return x .. " of a Kind (" .. val .. "s)"
    end
    if entry.hand.name == "Full House" and #entry.matched >= 5 then
        local counts = {}
        for _, v in ipairs(entry.matched) do
            counts[v] = (counts[v] or 0) + 1
        end
        local triple_val, pair_val
        for v, ct in pairs(counts) do
            if ct >= 3 then triple_val = v end
            if ct == 2 then pair_val = v end
        end
        if triple_val and pair_val then
            return "Full House (" .. triple_val .. "s + " .. pair_val .. "s)"
        end
    end
    return entry.hand.name
end

return Scoring
