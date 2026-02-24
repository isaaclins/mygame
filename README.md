# Let Die Ride!

**A Yahtzee Roguelike** — Roll. Lock. Score. Survive.

Built with [LÖVE2D](https://love2d.org/) (v11.5)

<!-- Add your own screenshots here: place images in docs/screenshots/ -->
<!-- Recommended: title.png, gameplay.png, shop.png, gameover.png -->

![Title Screen](docs/screenshots/title.png)
![Gameplay](docs/screenshots/gameplay.png)
![Shop](docs/screenshots/shop.png)

---

## What Is This?

Let Die Ride! is a roguelike deckbuilder — except instead of cards, you roll dice. Each round you roll your pool of dice and try to form scoring hands (like Yahtzee meets poker). Beat the target score to earn currency, then spend it in the shop to upgrade your hands, buy special dice, and collect powerful items. The target score scales exponentially, so you need a solid strategy to survive.

---

## Features

- **17 scorable hands** from High Roll to the elusive Pyramid
- **9 unique dice types** — Light, Heavy, Glass, Wild, Mirror, Echo, and more
- **7 collectible items** that alter scoring, economy, and dice behavior
- **5 boss encounters** every 4th round that twist the rules
- **Seeded runs** — share a seed, get the same game
- **Autosave** — quit anytime, pick up where you left off
- **Tutorial** — 20-step guided walkthrough for new players
- **Cross-platform** — macOS, Windows, Linux
- **Auto-updater** — checks GitHub releases for new versions

---

## How to Play

### The Basics

Each round, you need to hit a **target score** by forming hands from your dice pool. The target starts at 40 and scales by 1.35x each round — it gets steep fast.

### Round Flow

```
Roll all dice → Lock the keepers → Reroll the rest → Score your hand
```

1. **Roll** — All your dice are rolled automatically at the start of each round.
2. **Lock** — Click dice (or press 1-5 / Space) to lock ones you want to keep.
3. **Reroll** — Press R to reroll all unlocked dice. You start with 3 rerolls per round.
4. **Score** — Press Enter to submit. The game finds the best possible hand from your dice.

### Scoring

Your score is calculated as:

```
Score = (Hand Base + Sum of Matched Dice) × Hand Multiplier
```

Then dice abilities and item effects layer on top. For example, a **Three of a Kind** of 5s:

```
(30 base + 15 from dice) × 2.0 multiplier = 90 points
```

### The Shop

Beat a round and you enter the shop, where you can:

- **Buy special dice** that replace one of your existing dice
- **Upgrade hands** to increase their base score and multiplier
- **Buy items** that give passive or triggered bonuses
- **Expand your dice pool** (up to 10 dice)

Your first purchase each shop visit is **free** — choose wisely.

### Currency

After each round you earn currency from:

| Source | Amount |
|--------|--------|
| Base reward | max(5, target / 8) |
| Overkill bonus | score / 10 (if score >= 2× target) |
| Unused rerolls | 1 per reroll saved |
| Interest | 1 per $5 held (max 5) |

**Tip:** Hoarding currency for interest is a legitimate strategy — $25 in the bank nets you $5 interest every round.

### Boss Rounds

Every 4th round is a **boss round**. Bosses apply rule-bending modifiers:

| Boss | Effect |
|------|--------|
| The Lockdown | Locks a random die for the entire round |
| The Inverter | Flips all dice values after each roll (1↔6, 2↔5, 3↔4) |
| The Collector | Replaces a random die with a Normal Die after the round |
| The Miser | Reduces your rerolls by 2 |
| The Silencer | Suppresses all dice abilities |

---

## Hand Reference

Hands are detected automatically — the game always picks the best one.

| Hand | Requirement | Base | Mult |
|------|-------------|------|------|
| Pyramid | 1×2, 3×4, 5×6 (9+ dice) | 200 | ×10 |
| Seven of a Kind | 7+ same value | 175 | ×8 |
| Six of a Kind | 6+ same value | 130 | ×6 |
| Five of a Kind | 5+ same value | 100 | ×5 |
| Full Run | All 1-6 present (6+ dice) | 80 | ×4.5 |
| Two Triplets | 2 different triples (6+ dice) | 65 | ×4 |
| Four of a Kind | 4+ same value | 60 | ×3.5 |
| Three Pairs | 3 different pairs (6+ dice) | 50 | ×3 |
| Large Straight | 5 consecutive values | 45 | ×3 |
| Full House | Triple + Pair | 40 | ×2.5 |
| All Even | All dice even (5+ dice) | 40 | ×3 |
| All Odd | All dice odd (5+ dice) | 40 | ×3 |
| Small Straight | 4 consecutive values | 30 | ×2.5 |
| Three of a Kind | 3+ same value | 30 | ×2 |
| Two Pair | 2 different pairs | 20 | ×1.5 |
| Pair | 2 same value | 10 | ×1.5 |
| High Roll | Any single die | 5 | ×1 |

All hands can be upgraded up to level 5 in the shop (+30% base score and +0.5 multiplier per level).

---

## Dice Types

| Die | Ability | Description |
|-----|---------|-------------|
| Normal | — | Standard die, equal odds |
| Light | Featherweight | Only rolls 1, 2, or 3 |
| Heavy | Heavyweight | Only rolls 3, 4, 5, or 6 |
| Glass | Glass Cannon | x1.5 score mult when scored with, 10% shatter on reroll |
| Odd | Odd Synergy | +5 bonus when landing on an odd value |
| Even | Even Synergy | +5 bonus when landing on an even value |
| Wild | Wild Card | You choose its value each round |
| Mirror | Reflection | Flips value after rolling (1↔6, 2↔5, 3↔4) |
| Echo | Echo | Copies another random die's value |

---

## Controls

| Action | Key | Mouse |
|--------|-----|-------|
| Lock/Unlock die | 1-5 (or 0) / Space | Click die |
| Reroll | R | Click button |
| Score | Enter | Click button |
| Sort dice | Q | — |
| Show tooltip | E | — |
| Navigate | Arrow keys | — |
| Pause | Escape | — |

---

## Running the Game

### Prerequisites

- [LÖVE2D 11.5](https://love2d.org/)

### From Source

```bash
git clone https://github.com/isaaclins/letdieride.git
cd letdieride
love .
```

### Dev Mode (auto-restart on file change)

```bash
make dev
```

Requires `fswatch` (`brew install fswatch` on macOS). Falls back to 1-second polling if not installed.

### Sticker SVG Pipeline

Sticker artwork uses SVG as source and PNG as runtime texture for LÖVE.

```bash
make stickers
```

This converts `content/stickers/*.svg` into matching `*.png` files (same name) using the first available renderer:
- `rsvg-convert` (librsvg)
- `inkscape`
- `magick` (ImageMagick)

Optional output size:

```bash
STICKER_SIZE=768 make stickers
```

---

## Building

```bash
make build          # Build for current OS
make build-all      # Build for macOS, Windows, and Linux
make build-macos    # macOS .app bundle
make build-windows  # Windows .exe
make build-linux    # Linux AppImage wrapper
make love           # .love archive only
make clean          # Remove build outputs
```

Build artifacts go to `build/`. LÖVE binaries are cached in `build/.love-cache/` after first download.

---

## Project Structure

```
letdieride/
├── main.lua                 # Entry point, state machine, input routing
├── conf.lua                 # LÖVE configuration
├── version.lua              # Semantic version string
├── objects/                 # Game entities
│   ├── player.lua           # Player stats, dice pool, progression
│   ├── die.lua              # Die object with rolling and abilities
│   ├── hand.lua             # Hand scoring and upgrades
│   ├── item.lua             # Item triggers and effects
│   ├── boss.lua             # Boss modifier application
│   └── shop.lua             # Shop generation and pricing
├── content/                 # Game data definitions
│   ├── hands.lua            # 17 hand types with base scores
│   ├── dice_types.lua       # 8 dice types with abilities
│   ├── items.lua            # 7 items with effects
│   └── bosses.lua           # 5 boss encounters
├── states/                  # Game screens
│   ├── splash.lua           # Title screen
│   ├── seed_input.lua       # Seed entry
│   ├── round.lua            # Core gameplay
│   ├── shop_state.lua       # Shop between rounds
│   ├── game_over.lua        # Game over screen
│   ├── pause.lua            # Pause overlay
│   ├── settings.lua         # Settings screen
│   ├── tutorial.lua         # Interactive tutorial
│   └── devmenu.lua          # Debug menu
├── functions/               # Shared systems
│   ├── scoring.lua          # Hand detection & score calculation
│   ├── ui.lua               # UI toolkit (buttons, panels, dice rendering)
│   ├── rng.lua              # Seeded random number generator
│   ├── saveload.lua         # Save/load serialization
│   ├── updater.lua          # Auto-update checker
│   ├── settings.lua         # Settings persistence
│   ├── tween.lua            # Animation tweening engine
│   ├── particles.lua        # Particle effects
│   ├── transition.lua       # Screen transitions
│   ├── toast.lua            # Toast notifications
│   ├── fonts.lua            # Font cache
│   └── coin_anim.lua        # Coin sprite animation
├── content/sfx/             # Audio
├── content/icon/            # Icons and coin sprites
├── content/die/             # Die SVG assets
├── docs/                    # Documentation
│   ├── scoring.md           # Scoring algorithms
│   ├── dice.md              # Dice mechanics
│   ├── items-and-bosses.md  # Items and boss systems
│   ├── economy.md           # Shop, pricing, progression
│   └── technical.md         # RNG, save/load, architecture
└── .github/workflows/       # CI/CD release pipeline
```

---

## Documentation

Detailed documentation on game algorithms and systems lives in [`docs/`](docs/):

- [Scoring System](docs/scoring.md) — Hand detection algorithm, score formula, upgrade math
- [Dice Mechanics](docs/dice.md) — Dice types, weighted rolling, abilities
- [Items & Bosses](docs/items-and-bosses.md) — Item effects, boss modifiers
- [Economy & Progression](docs/economy.md) — Shop pricing, currency flow, target scaling
- [Technical Systems](docs/technical.md) — RNG, save/load, state machine, animation

---

## Adding Screenshots

Place screenshots in `docs/screenshots/` and they'll appear in this README:

```
docs/screenshots/title.png      # Title screen
docs/screenshots/gameplay.png   # Mid-round gameplay
docs/screenshots/shop.png       # Shop screen
docs/screenshots/gameover.png   # Game over screen (optional)
```

To capture screenshots in LÖVE2D, add this to any state's draw function:

```lua
if love.keyboard.isDown("f12") then
    love.graphics.captureScreenshot("screenshot.png")
end
```

---

## License

[Business Source License 1.1](LICENSE) — Free for non-commercial use. Converts to MIT on 2030-02-22.

Made by [Isaac Lins](https://github.com/isaaclins).
