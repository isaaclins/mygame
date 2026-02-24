# Sticker Migration Checklist

## Legacy cleanup
- [x] Mirror die removed from `content/dice_types.lua`.
- [x] Reverse behavior moved into sticker hook (`reverse`).
- [ ] Remove legacy die ability-only balancing assumptions where needed.

## Save compatibility
- [x] Die sticker payload serialized in `functions/saveload.lua`.
- [x] Sticker payload restored when loading runs.
- [ ] Add explicit save version migration step if future schema changes.

## Chaos-safety gates
- [x] Trigger budget guard.
- [x] Event-depth guard.
- [x] Chaos score surfaced in round top bar.
- [ ] Add boss-specific scaling thresholds tuned from playtest telemetry.

## UI rollout
- [x] Shop section remains in existing middle panel.
- [x] Section renamed to `RELICS & DIE MODS`.
- [x] Sticker hover popup with preview + stack label.
- [x] Sticker apply-to-die overlay flow.
