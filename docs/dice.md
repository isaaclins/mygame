# Dice Mechanics

This document covers how dice work, the rolling algorithm, weighted randomness, abilities, upgrades, and all 9 dice types.

**Source files:** `objects/die.lua`, `content/dice_types.lua`

---

## Die Object

Every die in the game has these properties:

| Property | Type | Description |
|----------|------|-------------|
| `name` | string | Display name (e.g., "Weighted Die") |
| `color` | string | Visual color: `"black"`, `"blue"`, `"green"`, or `"red"` |
| `die_type` | string | Type identifier (e.g., `"Weighted"`) |
| `value` | int | Current face value (1-6) |
| `locked` | bool | Whether the die is locked by the player |
| `boss_locked` | bool | Whether the die is locked by a boss |
| `rolling` | bool | Currently animating a roll |
| `roll_timer` | float | Remaining animation time |
| `weights` | float[6] | Weight for each face (default: all 1.0) |
| `ability` | function | Triggered after scoring |
| `ability_name` | string | Ability display name |
| `ability_desc` | string | Ability description |
| `upgrade_level` | int | Current upgrade level (0-3) |
| `max_upgrade` | int | Maximum upgrade level (default: 3) |
| `glow_color` | RGBA | Visual glow tint for special dice |
| `_sort_order` | int | Position in the dice pool for sorting |

---

## Rolling Algorithm

### Weighted Random Selection

The roll uses a weighted random algorithm. Each face has a weight, and the probability of landing on face `i` is:

```
P(face_i) = weight[i] / sum(all_weights)
```

Implementation:

```lua
function Die:roll()
    local total = 0
    for i = 1, 6 do
        total = total + self.weights[i]
    end

    local r = RNG.random() * total  -- random float in [0, total)
    local cumulative = 0
    for i = 1, 6 do
        cumulative = cumulative + self.weights[i]
        if r < cumulative then
            self.value = i
            break
        end
    end
end
```

### Normal Die Probabilities

With equal weights `{1, 1, 1, 1, 1, 1}`:

```
P(any face) = 1/6 ≈ 16.67%
```

### Light Die Probabilities

With weights `{1, 1, 1, 0, 0, 0}`, total = 3:

| Face | Weight | Probability |
|------|--------|-------------|
| 1 | 1 | 33.3% |
| 2 | 1 | 33.3% |
| 3 | 1 | 33.3% |
| 4 | 0 | 0% |
| 5 | 0 | 0% |
| 6 | 0 | 0% |

The Light Die can only roll 1, 2, or 3 with equal probability.

### Heavy Die Probabilities

With weights `{0, 0, 1, 1, 1, 1}`, total = 4:

| Face | Weight | Probability |
|------|--------|-------------|
| 1 | 0 | 0% |
| 2 | 0 | 0% |
| 3 | 1 | 25% |
| 4 | 1 | 25% |
| 5 | 1 | 25% |
| 6 | 1 | 25% |

The Heavy Die can only roll 3, 4, 5, or 6 with equal probability.

### Loaded Dice Item Effect

When the Loaded Dice item is active, all Normal dice get weights `{0.8, 0.8, 1.0, 1.1, 1.2, 1.3}`, total = 6.2:

| Face | Weight | Probability |
|------|--------|-------------|
| 1 | 0.8 | 12.9% |
| 2 | 0.8 | 12.9% |
| 3 | 1.0 | 16.1% |
| 4 | 1.1 | 17.7% |
| 5 | 1.2 | 19.4% |
| 6 | 1.3 | 21.0% |

Subtler than the Heavy Die, but shifts probability toward higher values across multiple dice.

---

## Roll Animation

Rolling is visual — the actual value is determined at the end.

```lua
function Die:startRoll(duration)
    self.rolling = true
    self.roll_timer = duration or (0.4 + math.random() * 0.3)
end
```

During `update(dt)`:
- While `roll_timer > 0`: display value randomizes each frame (visual tumble)
- When `roll_timer` hits 0: `die:roll()` sets the final weighted-random value, `rolling = false`

Rerolls use a shorter animation: `0.3 + math.random() * 0.2` seconds.

---

## Post-Roll Processing

After all dice finish rolling, two special mechanics trigger:

### 1. Mirror Die Flip

If the die type is Mirror, after `roll()`:

```lua
self.value = 7 - self.value
```

This maps: 1↔6, 2↔5, 3↔4.

### 2. Echo Die Copy

Echo dice copy the value of another random non-Echo die:

```lua
local candidates = {}
for _, d in ipairs(player.dice_pool) do
    if d.die_type ~= "Echo" and d ~= self then
        table.insert(candidates, d)
    end
end
if #candidates > 0 then
    self.value = candidates[RNG.random(1, #candidates)].value
end
```

Processing order: Mirror flips happen first, then Echo copies. This means an Echo die can copy a Mirror die's already-flipped value.

---

## Dice Abilities

Abilities fire during the scoring phase. Each ability receives the die, the score context, and the upgrade level.

### Ability Trigger Flow

```
1. Gather all dice values
2. Detect best hand
3. Calculate base score
4. For each die: fire ability (unless boss suppresses)
5. Sum up bonuses
6. Apply item multipliers
7. Final score
```

---

## All 9 Dice Types

### Normal Die

| Property | Value |
|----------|-------|
| Color | Black |
| Weights | {1, 1, 1, 1, 1, 1} |
| Ability | None |
| Description | A standard die. |

The baseline. Equal probability on all faces, no special effects.

---

### Light Die

| Property | Value |
|----------|-------|
| Color | Blue |
| Weights | {1, 1, 1, 0, 0, 0} |
| Ability | Featherweight |
| Glow | Light Blue (0.6, 0.85, 1.0, 0.6) |

Can only roll 1, 2, or 3. Useful for targeting low-value hands, synergy with Odd Die (2 of 3 faces are odd), and predictable outcomes. Pairs well with Mirror Die (which would flip 1→6, 2→5, 3→4).

---

### Heavy Die

| Property | Value |
|----------|-------|
| Color | Blue |
| Weights | {0, 0, 1, 1, 1, 1} |
| Ability | Heavyweight |
| Glow | Dark Blue (0.2, 0.25, 0.7, 0.6) |

Can only roll 3, 4, 5, or 6. The higher floor makes it excellent for N-of-a-Kind strategies since face values contribute to score. Overlaps with Light Die on the value 3, enabling interesting pair/set combos.

---

### Glass Die

| Property | Value |
|----------|-------|
| Color | Red |
| Weights | {1, 1, 1, 1, 1, 1} |
| Ability | Fragile Fortune |
| Glow | Red (1.0, 0.3, 0.3, 0.2) |

**Scoring bonus:** +10 flat bonus (+5 per upgrade level).

**Break mechanic:** 20% chance to shatter after each round. When a Glass Die breaks, it permanently becomes a Normal Die (type, name, color, ability, glow, and weights all reset).

The Insurance item prevents the first Glass Die break per round.

| Upgrade Level | Bonus |
|---------------|-------|
| 0 | +10 |
| 1 | +15 |
| 2 | +20 |
| 3 | +25 |

---

### Odd Die

| Property | Value |
|----------|-------|
| Color | Green |
| Weights | {1, 1, 1, 1, 1, 1} |
| Ability | Odd Synergy |
| Glow | Green (0.2, 1.0, 0.3, 0.2) |

**Scoring bonus:** +5 flat bonus (+3 per upgrade level) when the die's value is odd (1, 3, or 5).

Fires on odd values only. With equal weights, triggers ~50% of the time.

| Upgrade Level | Bonus (when odd) |
|---------------|-----------------|
| 0 | +5 |
| 1 | +8 |
| 2 | +11 |
| 3 | +14 |

---

### Even Die

| Property | Value |
|----------|-------|
| Color | Green |
| Weights | {1, 1, 1, 1, 1, 1} |
| Ability | Even Synergy |
| Glow | Green (0.2, 1.0, 0.3, 0.2) |

Identical to Odd Die but triggers on even values (2, 4, 6). Same bonus progression.

---

### Wild Die

| Property | Value |
|----------|-------|
| Color | Red |
| Weights | {1, 1, 1, 1, 1, 1} |
| Ability | Wild Card |
| Glow | Gold (1.0, 0.84, 0, 0.25) |

The player manually sets this die's value each round by clicking it and choosing 1-6. The die still rolls visually, but the player overrides the result.

Extremely powerful for completing specific hands (e.g., guaranteeing a straight or boosting N-of-a-Kind).

---

### Mirror Die

| Property | Value |
|----------|-------|
| Color | Blue |
| Weights | {1, 1, 1, 1, 1, 1} |
| Ability | Reflection |
| Glow | Cyan (0.4, 0.8, 1.0, 0.2) |

After rolling, the value is flipped: `value = 7 - value`.

| Rolled | Becomes |
|--------|---------|
| 1 | 6 |
| 2 | 5 |
| 3 | 4 |
| 4 | 3 |
| 5 | 2 |
| 6 | 1 |

Effectively equal probability on all faces (just remapped). Strategic value comes from interaction with The Inverter boss (double-flip = no flip) and pairing with other dice for predictable combos.

---

### Echo Die

| Property | Value |
|----------|-------|
| Color | Blue |
| Weights | {1, 1, 1, 1, 1, 1} |
| Ability | Echo |
| Glow | Purple (0.6, 0.3, 1.0, 0.25) |

After all dice finish rolling, the Echo Die copies the value of a random non-Echo die in the pool. If there are no non-Echo dice, it keeps its rolled value.

Excellent for boosting N-of-a-Kind odds since it duplicates an existing value. With 4 normal dice and 1 Echo, you're guaranteed at least a Pair.

---

## Dice Upgrades

Dice can be upgraded in the shop up to their `max_upgrade` (default 3). Upgrades improve ability bonuses:

| Die | Upgrade Effect |
|-----|----------------|
| Glass | +5 bonus per level |
| Odd | +3 bonus per level (when triggering) |
| Even | +3 bonus per level (when triggering) |
| Normal, Light, Heavy, Wild, Mirror, Echo | No upgrade bonus (abilities are stat-independent) |

Upgrade cost is included in the die's shop price: `8 + upgrade_level × 4`.
