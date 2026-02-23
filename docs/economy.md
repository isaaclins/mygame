# Economy & Progression

This document covers the currency system, shop mechanics, pricing formulas, target score scaling, and overall game economy.

**Source files:** `states/shop_state.lua`, `objects/shop.lua`, `objects/player.lua`, `states/round.lua`

---

## Target Score Scaling

The target score determines what you need to beat each round. It follows an exponential curve:

```lua
target = floor(40 × 1.35 ^ (round - 1))
```

### Target Score Table

| Round | Target | Boss? | Notes |
|-------|--------|-------|-------|
| 1 | 40 | | Starting target |
| 2 | 54 | | |
| 3 | 72 | | |
| 4 | 97 | Boss | First boss round |
| 5 | 131 | | |
| 6 | 177 | | |
| 7 | 239 | | |
| 8 | 323 | Boss | |
| 9 | 436 | | |
| 10 | 588 | | |
| 12 | 1,072 | Boss | |
| 15 | 2,283 | | |
| 16 | 3,082 | Boss | |
| 20 | 10,447 | Boss | |
| 25 | 48,474 | | |
| 30 | 224,785 | | |

The target roughly doubles every 2.5 rounds. By round 20, you need over 10,000 points per round.

### Implications

- **Early game (rounds 1-5):** Most hands can hit the target. Focus on building your economy.
- **Mid game (rounds 6-12):** Need upgraded hands and/or dice abilities to keep up.
- **Late game (rounds 13+):** Requires strong synergies — high-level hands, ability stacking, and multiplier items.

---

## Currency System

### Earning Currency

After winning a round, currency is awarded from multiple sources:

```lua
function Player:earnCurrency(score)
    local target = self:getTargetScore()

    local base = math.max(5, math.floor(target / 8))
    local overkill = 0
    if score >= target * 2 then
        overkill = math.floor(score / 10)
    end
    local unused = self.rerolls_remaining
    local interest = math.min(5, math.floor(self.currency / 5))

    local total = base + overkill + unused + interest
    self.currency = self.currency + total

    return {
        base = base,
        overkill = overkill,
        unused_rerolls = unused,
        interest = interest,
        total = total,
    }
end
```

### Earnings Breakdown

| Source | Formula | Notes |
|--------|---------|-------|
| Base reward | `max(5, floor(target / 8))` | Scales with round difficulty |
| Overkill bonus | `floor(score / 10)` | Only if score ≥ 2× target |
| Unused rerolls | 1 per reroll saved | Max 3 (or 4 with Extra Reroll) |
| Interest | `min(5, floor(currency / 5))` | 1 per $5 held, capped at 5 |
| Lucky Penny | +3 flat | If item is owned |

### Interest Strategy

Interest is capped at $5 per round (requiring $25+ in the bank). This creates a meaningful decision: spend currency now on upgrades, or save for compound interest.

| Currency Held | Interest |
|---------------|----------|
| $0-4 | $0 |
| $5-9 | $1 |
| $10-14 | $2 |
| $15-19 | $3 |
| $20-24 | $4 |
| $25+ | $5 (cap) |

Over 10 rounds at max interest, that's $50 — more than enough to fund major upgrades.

### Earnings by Round (no overkill, 0 rerolls saved, no items)

| Round | Target | Base Reward | Interest (at $0) | Total |
|-------|--------|-------------|-------------------|-------|
| 1 | 40 | 5 | 0 | 5 |
| 5 | 131 | 16 | varies | 16+ |
| 10 | 588 | 73 | varies | 73+ |
| 15 | 2,283 | 285 | 5 (cap) | 290+ |
| 20 | 10,447 | 1,305 | 5 (cap) | 1,310+ |

Base rewards scale linearly with the target, but costs are fixed — the economy becomes increasingly generous in later rounds if you can survive.

---

## Shop Mechanics

### Shop Generation

Each shop visit generates fresh offerings:

| Category | Count | Source |
|----------|-------|--------|
| Dice | Up to 3 | Random from all dice types (no duplicates in offering) |
| Items | Up to 3 | Random from items the player doesn't own |
| Hand upgrades | Up to 5 | Random from hands not at max level and with `min_dice` met |

### Free Choice

Every shop visit, the **first purchase** is free. This applies to:
- Buying a die
- Buying a hand upgrade
- Replacing a die (the new die costs nothing)

After the free choice is used, normal pricing applies for the rest of the visit.

The flag `player.free_choice_used` resets to `false` at the start of each shop visit.

---

## Pricing

### Die Prices

```lua
cost = 8 + die.upgrade_level × 4
```

| Upgrade Level | Price |
|---------------|-------|
| 0 | $8 |
| 1 | $12 |
| 2 | $16 |
| 3 | $20 |

Buying a die from the shop **replaces** an existing die in your pool. The player picks which die to swap out via an overlay.

### Item Prices

Each item has a fixed cost defined in its template:

| Item | Cost |
|------|------|
| Lucky Penny | $8 |
| Extra Reroll | $10 |
| Insurance | $12 |
| Even Steven | $15 |
| Odd Todd | $15 |
| Loaded Dice | $18 |
| High Roller | $20 |

### Hand Upgrade Prices

```lua
cost = 5 + level² × 5
```

Where `level` is the current level (before upgrading).

| Upgrade | Cost | Cumulative |
|---------|------|------------|
| 0 → 1 | $5 | $5 |
| 1 → 2 | $10 | $15 |
| 2 → 3 | $25 | $40 |
| 3 → 4 | $50 | $90 |
| 4 → 5 | $85 | $175 |

The quadratic cost curve means early upgrades are cheap, but maxing a hand is expensive. Spreading upgrades across multiple hands is often more cost-effective than maxing one.

### Extra Die Slot Prices

```lua
cost = 15 + extra² × 10
```

Where `extra = max(0, current_pool_size - 5)`.

| Pool Size | Buying Slot | Cost | Cumulative |
|-----------|-------------|------|------------|
| 5 | 6th die | $15 | $15 |
| 6 | 7th die | $25 | $40 |
| 7 | 8th die | $55 | $95 |
| 8 | 9th die | $105 | $200 |
| 9 | 10th die | $175 | $375 |

Maximum pool size is **10 dice**. Extra slots add a "Vanilla Die" (functionally identical to Normal Die).

---

## Economy Analysis

### Early Game ($0 starting)

The player starts with zero currency. Round 1 yields ~$5-8 (base + potential reroll savings). Key decisions:

- **Round 1-3 earnings:** ~$15-25 total
- **Affordable:** Cheap hand upgrades ($5), Lucky Penny ($8), or save for interest
- **Free choice:** Use it on the most impactful single purchase

### Mid Game (rounds 5-10)

Base rewards scale up significantly. With interest at $3-5/round:

- **Per-round income:** $30-80+
- **Affordable:** Multiple hand upgrades, specialty dice, most items
- **Key investment:** Upgrading your most-used hand to level 3-4

### Late Game (rounds 15+)

Currency is abundant but targets are extreme:

- **Per-round income:** $200+
- **Strategy:** Max out key hands, fill pool with synergistic dice
- **Diminishing returns:** Many upgrades are already maxed; extra currency has limited spending options

### Return on Investment (ROI)

| Investment | Cost | Impact | ROI |
|------------|------|--------|-----|
| Lucky Penny | $8 | +$3/round forever | Breaks even in 3 rounds |
| Hand upgrade 0→1 | $5 | +30% base, +0.5 mult | Immediate scoring boost |
| Extra Reroll | $10 | +1 reroll/round | Better hand selection |
| Extra die slot (6th) | $15 | Access to 6-dice hands | Unlocks Full Run, Two Triplets, etc. |
| Glass Die | $8 | x1.5 score mult when scored, 10% shatter on reroll | Lock to protect, reroll at your peril |

---

## Progression Curve

The game's difficulty is an arms race between exponential target growth and the player's linear-ish power scaling:

```
Target: 40 × 1.35^(r-1)     — exponential
Scoring: base × mult + bonuses — linear upgrades to base & mult
```

The player's power grows through:
1. **Hand upgrades** (+30% base, +0.5 mult per level) — diminishing, capped at level 5
2. **Dice pool expansion** — more dice = access to stronger hands
3. **Dice abilities** — flat bonuses that become relatively weaker over time
4. **Items** — multiplier items (Even Steven, Odd Todd) scale better than flat bonuses

Eventually the exponential target outpaces the player's power growth, creating a natural difficulty ceiling. Skilled play and good RNG extend the run, but all runs eventually end — unless the player invests in the Limit Breaker.

---

## Limit Breaker (Infinite Mode)

The **Limit Breaker** is a consumable item that raises all upgrade caps, enabling infinite scaling runs.

### Availability

Appears in the shop when **either** condition is met:
- Player has reached round 10
- Any hand upgrade is at max level

### Cost

Scales exponentially with each purchase:

```lua
cost = 500 × 2^(limit_break_count)
```

| Purchase | Cost | Cumulative |
|----------|------|------------|
| 1st | $500 | $500 |
| 2nd | $1,000 | $1,500 |
| 3rd | $2,000 | $3,500 |
| 4th | $4,000 | $7,500 |
| 5th | $8,000 | $15,500 |
| 6th | $16,000 | $31,500 |

### Effect (per purchase)

| Cap | Increase | Starting | After 1 | After 2 |
|-----|----------|----------|---------|---------|
| Hand max upgrade | +5 | 5 | 10 | 15 |
| Die max upgrade | +2 | 3 | 5 | 7 |
| Dice pool max | +2 | 5 | 7 | 9 |
| Interest cap | +3 | 5 | 8 | 11 |

### Post-Cap Hand Upgrade Costs

Hand upgrades past the original level 5 cap use a steeper cost formula:

```lua
-- Levels 0-4: cost = 5 + level² × 5
-- Levels 5+:  cost = 5 + level² × 8
```

| Upgrade | Cost (post-cap) |
|---------|----------------|
| 5 → 6 | $205 |
| 10 → 11 | $805 |
| 15 → 16 | $1,805 |
| 20 → 21 | $3,205 |

### Strategy

The Limit Breaker creates sustained tension between:
1. **Buying more Limit Breakers** to unlock higher caps (exponentially expensive)
2. **Investing in upgrades** within the current caps (quadratically expensive)

Each hand upgrade gives ~+31% score. The target grows 35% per round. Players need roughly one key upgrade per round to stay alive, making the infinite run a tight resource management challenge.
