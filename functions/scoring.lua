local Scoring = {}

function Scoring.getCounts(values)
    local counts = {}
    for _, v in ipairs(values) do
        counts[v] = (counts[v] or 0) + 1
    end
    return counts
end

function Scoring.getSorted(values)
    local sorted = {}
    for _, v in ipairs(values) do
        table.insert(sorted, v)
    end
    table.sort(sorted)
    return sorted
end

function Scoring.hasConsecutive(sorted, n)
    local unique = {}
    local seen = {}
    for _, v in ipairs(sorted) do
        if not seen[v] then
            table.insert(unique, v)
            seen[v] = true
        end
    end
    table.sort(unique)

    if #unique < n then return false, {} end

    for i = 1, #unique - n + 1 do
        local is_seq = true
        for j = 1, n - 1 do
            if unique[i + j] ~= unique[i] + j then
                is_seq = false
                break
            end
        end
        if is_seq then
            local matched = {}
            for j = 0, n - 1 do
                table.insert(matched, unique[i + j])
            end
            return true, matched
        end
    end
    return false, {}
end

function Scoring.detectHand(values)
    local counts = Scoring.getCounts(values)
    local sorted = Scoring.getSorted(values)
    local n = #values

    local max_count = 0
    for _, count in pairs(counts) do
        if count > max_count then max_count = count end
    end

    local pairs_found = {}
    local threes_found = {}
    local fours_found = {}

    for val, count in pairs(counts) do
        if count >= 2 then table.insert(pairs_found, val) end
        if count >= 3 then table.insert(threes_found, val) end
        if count >= 4 then table.insert(fours_found, val) end
    end

    -- Detection order: strongest hand first (by base_score * multiplier)

    -- Pyramid: 1×2, 3×4, 5×6 (200 x 10)
    if n >= 9 and (counts[2] or 0) >= 1 and (counts[4] or 0) >= 3 and (counts[6] or 0) >= 5 then
        local matched = { 2, 4, 4, 4, 6, 6, 6, 6, 6 }
        return "Pyramid", matched
    end

    -- Seven of a Kind (175 x 8)
    if max_count >= 7 then
        return "Seven of a Kind", values
    end

    -- Six of a Kind (130 x 6)
    if max_count >= 6 then
        local matched = {}
        for val, count in pairs(counts) do
            if count >= 6 then
                for i = 1, count do table.insert(matched, val) end
            end
        end
        return "Six of a Kind", matched
    end

    -- Five of a Kind (100 x 5)
    if max_count >= 5 then
        return "Five of a Kind", values
    end

    -- Full Run: all values 1-6 present, 6+ dice (80 x 4.5)
    if n >= 6 then
        local has_all = true
        for v = 1, 6 do
            if not counts[v] then has_all = false; break end
        end
        if has_all then
            return "Full Run", { 1, 2, 3, 4, 5, 6 }
        end
    end

    -- Two Triplets: two different 3-of-a-kind, 6+ dice (65 x 4)
    if #threes_found >= 2 then
        local matched = {}
        local used = 0
        for _, val in ipairs(threes_found) do
            if used < 2 then
                for i = 1, counts[val] do table.insert(matched, val) end
                used = used + 1
            end
        end
        return "Two Triplets", matched
    end

    -- Four of a Kind (60 x 3.5)
    if #fours_found > 0 then
        local matched = {}
        for _, v in ipairs(values) do
            if v == fours_found[1] then table.insert(matched, v) end
        end
        return "Four of a Kind", matched
    end

    -- Three Pairs: three different pairs, 6+ dice (50 x 3)
    if #pairs_found >= 3 then
        local matched = {}
        for _, val in ipairs(pairs_found) do
            for i = 1, math.min(counts[val], 2) do
                table.insert(matched, val)
            end
        end
        return "Three Pairs", matched
    end

    -- Large Straight: 5 consecutive (45 x 3)
    local has_large, large_matched = Scoring.hasConsecutive(sorted, 5)
    if has_large then
        return "Large Straight", large_matched
    end

    -- Full House: three of a kind + a pair (40 x 2.5)
    if #threes_found > 0 and #pairs_found > 1 then
        return "Full House", values
    end

    -- All Even: every die even, 5+ dice (40 x 3)
    if n >= 5 then
        local all_even = true
        for _, v in ipairs(values) do
            if v % 2 ~= 0 then all_even = false; break end
        end
        if all_even then
            return "All Even", values
        end
    end

    -- All Odd: every die odd, 5+ dice (40 x 3)
    if n >= 5 then
        local all_odd = true
        for _, v in ipairs(values) do
            if v % 2 ~= 1 then all_odd = false; break end
        end
        if all_odd then
            return "All Odd", values
        end
    end

    -- Small Straight: 4 consecutive (30 x 2.5)
    local has_small, small_matched = Scoring.hasConsecutive(sorted, 4)
    if has_small then
        return "Small Straight", small_matched
    end

    -- Three of a Kind (30 x 2)
    if #threes_found > 0 then
        local matched = {}
        for _, v in ipairs(values) do
            if v == threes_found[1] then table.insert(matched, v) end
        end
        return "Three of a Kind", matched
    end

    -- Two Pair (20 x 1.5)
    if #pairs_found >= 2 then
        local matched = {}
        for _, v in ipairs(values) do
            for _, pv in ipairs(pairs_found) do
                if v == pv then
                    table.insert(matched, v)
                    break
                end
            end
        end
        return "Two Pair", matched
    end

    -- Pair (10 x 1.5)
    if #pairs_found == 1 then
        local matched = {}
        for _, v in ipairs(values) do
            if v == pairs_found[1] then table.insert(matched, v) end
        end
        return "Pair", matched
    end

    -- High Roll: fallback (5 x 1)
    return "High Roll", { math.max(unpack(values)) }
end

function Scoring.findBestHand(values, hands_list)
    local hand_name, matched = Scoring.detectHand(values)
    for _, hand in ipairs(hands_list) do
        if hand.name == hand_name then
            local score = hand:calculateScore(values, matched)
            return hand, score, matched
        end
    end
    return hands_list[1], hands_list[1]:calculateScore(values, matched), matched
end

return Scoring
