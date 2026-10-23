## Skill levels from XP, and how levels and tea buffs ease each minigame.
class_name Skills
extends RefCounted

const NAMES := ["mechanics", "electronics", "diagnostics", "craft", "piloting"]
const LABELS := {
	"mechanics": "Mechanics", "electronics": "Electronics", "diagnostics": "Diagnostics", "craft": "Craft",
	"piloting": "Piloting",
}
## Total XP needed to reach each level, starting at level 1.
const THRESHOLDS := [0, 60, 150, 280, 450, 680, 980]


static func level(xp: int) -> int:
	var lvl := 0
	for t in THRESHOLDS:
		if xp >= t:
			lvl += 1
	return lvl


## 0..1 progress from the current level toward the next (1 at max level).
static func progress(xp: int) -> float:
	var lvl := level(xp)
	if lvl >= THRESHOLDS.size():
		return 1.0
	var lo: int = THRESHOLDS[lvl - 1]
	return float(xp - lo) / (THRESHOLDS[lvl] - lo)


## How forgiving a minigame is: 1.0 at level 1 with no tea, growing with skill and buffs.
static func ease(xp: int, buff_bonus: float) -> float:
	return 1.0 + (level(xp) - 1) * 0.12 + buff_bonus
