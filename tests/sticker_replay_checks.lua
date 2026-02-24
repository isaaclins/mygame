-- Manual deterministic replay checks for sticker system.
-- Run inside game debug tooling by simulating seeded rounds.

local checks = {
	"Seed A: all_in + jackpot should not exceed trigger guard budget.",
	"Seed B: bad_luck stack scaling should reduce death chance as stacks increase.",
	"Seed C: reverse + risk_reward should keep die values clamped to [1,6].",
	"Seed D: lucky_streak should add rerolls on repeated in-round values only.",
	"Seed E: save/load should preserve sticker stacks and visual transforms.",
}

return checks
