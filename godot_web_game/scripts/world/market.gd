## Prices at the dock market today: list price, the day's drift and any market event (see Trade),
## after the player's perks.
class_name Market
extends RefCounted

## Share of the market price you get when selling a part back, before perks.
const RESALE := 0.6


static func today(part_id: String) -> float:
	return Content.part(part_id).price * Trade.factor(GameState.run_seed, GameState.day, part_id,
		Content.part(part_id).slot, Content.trade)


static func price(part_id: String) -> int:
	return roundi(today(part_id) * (1.0 - GameState.perk("parts_discount")))


static func resale(part_id: String) -> int:
	return roundi(today(part_id) * (RESALE + GameState.perk("resale")))


## Worn parts sell cheap and fetch half the resale of a sound one.
static func worn_price(part_id: String) -> int:
	return roundi(today(part_id) * float(Content.trade.worn_value))


static func worn_resale(part_id: String) -> int:
	return roundi(resale(part_id) * float(Content.trade.worn_resale))


## Today's market news, or "".
static func news() -> String:
	var ev := Trade.event(GameState.run_seed, GameState.day, Content.trade)
	return Content.trade.events[ev].news if ev else ""
