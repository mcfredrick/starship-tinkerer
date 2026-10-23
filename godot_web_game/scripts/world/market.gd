## Prices at the dock market, after the player's perks.
class_name Market
extends RefCounted

## Share of the market price you get when selling a part back, before perks.
const RESALE := 0.6


static func price(part_id: String) -> int:
	return roundi(Content.part(part_id).price * (1.0 - GameState.perk("parts_discount")))


static func resale(part_id: String) -> int:
	return roundi(Content.part(part_id).price * (RESALE + GameState.perk("resale")))
