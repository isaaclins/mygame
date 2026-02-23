# Items & Bosses

This document covers all collectible items, their trigger systems, and all boss encounters with their rule-modifying effects.

**Source files:** `content/items.lua`, `objects/item.lua`, `content/bosses.lua`, `objects/boss.lua`

---

## Item System

### Trigger Types

Items have one of two trigger types:

| Type | When It Fires | Can Fire Multiple Times? |
|------|---------------|--------------------------|
| `"passive"` | At the start of each round (`round_start` phase) | Yes, every round |
| `"once"` | During scoring or earning, once per round | No, resets each round |

The `triggered_this_round` flag prevents "once" items from double-firing. It resets when a new round starts via `player:startNewRound()`.

### Item Uniqueness

Items are unique — you can only own one of each. The shop filters out items the player already has when generating offerings.

---

## All 7 Items

### Extra Reroll — $10

| Property | Value |
|----------|-------|
| Trigger | Passive (round_start) |
| Effect | +1 to max rerolls per round |

Fires at the start of every round, permanently increasing rerolls by 1 for that round. Stacks with base rerolls (default 3), so you'd have 4 rerolls per round.

---

### Even Steven — $15

| Property | Value |
|----------|-------|
| Trigger | Once (scoring) |
| Effect | +0.5 multiplier bonus per even-valued die |

During scoring, counts all dice showing even values (2, 4, 6) and adds 0.5 to the multiplier bonus for each. With 5 dice all showing even values, that's +2.5 to the multiplier.

**Applied as:** `score = floor(score × (1 + mult_bonus))`

Example with 3 even dice and a base score of 90:

```
mult_bonus = 3 × 0.5 = 1.5
final = floor(90 × (1 + 1.5)) = floor(90 × 2.5) = 225
```

---

### Odd Todd — $15

| Property | Value |
|----------|-------|
| Trigger | Once (scoring) |
| Effect | +0.5 multiplier bonus per odd-valued die |

Same as Even Steven but for odd values (1, 3, 5). These two items can be combined — with a full pool of 5 dice, you're guaranteed at least 2-3 triggers from one of them.

---

### Lucky Penny — $8

| Property | Value |
|----------|-------|
| Trigger | Once (earn phase) |
| Effect | +3 currency after each round |

Fires during the currency-earning phase. A flat +3 per round regardless of performance. Over 10 rounds, that's 30 extra currency — easily pays for itself.

---

### Insurance — $12

| Property | Value |
|----------|-------|
| Trigger | Passive (round_start) |
| Effect | Prevents the first Glass Die from breaking this round |

Sets a flag that the break mechanic checks. If a Glass Die would shatter, the flag is consumed instead and the die survives. Only protects one die per round — if you have multiple Glass Dice, subsequent ones can still break.

---

### High Roller — $20

| Property | Value |
|----------|-------|
| Trigger | Once (scoring) |
| Effect | +15 flat bonus to score |

A straightforward +15 added to the score after the base hand calculation but before item multiplier bonuses. Most impactful in the early game when scores are low.

---

### Loaded Dice — $18

| Property | Value |
|----------|-------|
| Trigger | Passive (round_start) |
| Effect | All Normal dice get weights {0.8, 0.8, 1.0, 1.1, 1.2, 1.3} |

At round start, modifies the weight table of every Normal-type die in the pool. This shifts their probability distribution toward higher values:

| Face | Normal P% | Loaded P% | Difference |
|------|-----------|-----------|------------|
| 1 | 16.7% | 12.9% | -3.8% |
| 2 | 16.7% | 12.9% | -3.8% |
| 3 | 16.7% | 16.1% | -0.6% |
| 4 | 16.7% | 17.7% | +1.0% |
| 5 | 16.7% | 19.4% | +2.7% |
| 6 | 16.7% | 21.0% | +4.3% |

The effect is subtle per die but compounds across multiple Normal dice. Does not affect non-Normal dice types.

---

## Item Strategy Notes

### Synergy Combos

| Combo | Effect |
|-------|--------|
| Even Steven + Even Dice | Even Dice guarantee even values, maximizing the multiplier bonus |
| Odd Todd + Odd Dice | Same synergy for odd values |
| Insurance + Glass Dice | Protects your highest-risk, highest-reward dice |
| Loaded Dice + many Normals | Maximizes the statistical advantage across your pool |
| Extra Reroll + The Miser | Partially counters the boss's reroll reduction |
| Lucky Penny + interest hoarding | Accelerates currency accumulation for compound interest |
| X of a Kind upgrade + large pool | With 10+ dice, multi-hand scoring can form multiple X-of-a-Kind combos |

---

## Boss System

### When Bosses Appear

Bosses appear every 4th round:

```lua
function Player:isBossRound()
    return self.round % 4 == 0
end
```

Rounds 4, 8, 12, 16, 20, ... are boss rounds.

### Boss Selection

A random boss is chosen from the full pool each time:

```lua
current_boss = all_bosses[RNG.random(1, #all_bosses)]
```

The same boss can appear multiple times across a run.

### Boss Lifecycle

```
1. applyModifier(context) — called at round start
2. Round plays out with modifier active
3. revertModifier(context) — called when leaving the round
```

The `context` table carries state between apply and revert (e.g., which die was locked).

---

## All 5 Bosses

### The Lockdown

| Property | Value |
|----------|-------|
| Icon | X |
| Modifier | Locks 30% of dice (min 1) to random values |

**Apply:** Randomly selects 30% of the dice pool (minimum 1, rounded up) and locks each to a random value (1-6). The player cannot unlock these dice for the entire round.

**Revert:** Unlocks all boss-locked dice.

**Visual:** Boss-locked dice show a bobbing purple "?" above them instead of the normal red lock badge.

**Counter-play:** Wild Dice are immune (their value is player-controlled). Scales with pool size — at 10 dice, 3 are locked; at 5 dice, 2 are locked.

---

### The Inverter

| Property | Value |
|----------|-------|
| Icon | ~ |
| Modifier | Flips all dice values after each roll |

**Apply:** Sets a flag that causes all unlocked dice to have their values inverted after every roll: `value = 7 - value`.

This is applied **after** the normal roll, so:
- A rolled 1 becomes 6
- A rolled 6 becomes 1
- A rolled 3 stays 4

**Interaction with Mirror Die:** Mirror dice flip once (their ability), then The Inverter flips them again. Double-flip cancels out — Mirror Dice are effectively immune to The Inverter.

**Revert:** Removes the inversion flag.

**Counter-play:** Mirror Dice cancel the effect. Heavy Dice (restricted to 3-6) become effectively weaker since inverted values land in the 1-4 range. Light Dice (restricted to 1-3) benefit since inverted values land in the 4-6 range.

---

### The Collector

| Property | Value |
|----------|-------|
| Icon | ? |
| Modifier | Steals a die after the round |

**Apply:** No immediate effect during the round.

**Revert (post-round):** Picks a random die from the pool and replaces it with a Normal Die. The original die's type, ability, and upgrades are lost.

**Counter-play:** This is the most punishing boss for players invested in special dice. There's no way to prevent it — it's a tax on your dice pool. Having more dice means a lower chance of losing your best one.

---

### The Miser

| Property | Value |
|----------|-------|
| Icon | - |
| Modifier | Reduces rerolls by 2 |

**Apply:** `player.max_rerolls = max(0, player.max_rerolls - 2)` and also reduces `rerolls_remaining` by 2 (floored at 0).

**Revert:** Restores the original `max_rerolls` value.

With the default 3 rerolls, you're left with just 1. With the Extra Reroll item (4 total), you'd have 2.

**Counter-play:** Extra Reroll item, Wild Dice (less dependent on rerolls), locking strategy (lock good dice early to reduce reroll dependency).

---

### The Silencer

| Property | Value |
|----------|-------|
| Icon | ! |
| Modifier | Suppresses all dice abilities |

**Apply:** Sets a flag that prevents all dice abilities from firing during the scoring phase.

**Revert:** Removes the suppression flag.

This disables: Glass Die bonus, Odd/Even Die bonus, Echo copying, Mirror flipping (ability is suppressed, so no post-roll flip). However, weight tables are still in effect (Light Die still only rolls 1-3, Heavy Die still only rolls 3-6, Loaded Dice item still applies).

**Counter-play:** Rely on hand strength and hand upgrades rather than dice abilities. Items still work normally (Even Steven, Odd Todd, High Roller, etc.).

---

## Boss Difficulty Scaling

Bosses don't scale — the same boss has the same effect in round 4 as in round 100. The difficulty increase comes entirely from the exponentially scaling target score. However, bosses become relatively more punishing in later rounds because:

- The Miser's reroll reduction matters more when targets are high
- The Collector's die theft is more costly when dice are upgraded
- The Silencer removes increasingly powerful ability bonuses
- The Lockdown wastes a die you've invested in
- The Inverter disrupts carefully built dice synergies
