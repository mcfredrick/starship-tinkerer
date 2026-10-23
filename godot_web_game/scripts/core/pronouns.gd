## Fills {name}, pronoun and verb-agreement tokens in dialogue for the player or any pilot.
##
## Tokens: {name}, {they} {them} {their} {theirs} {themself}, capitalized forms ({They}...),
## and {singular|plural} pairs for verbs ("{they} {is|are}") that follow the pronoun's grammar.
class_name Pronouns
extends RefCounted

const SETS := {
	"she": {"they": "she", "them": "her", "their": "her", "theirs": "hers", "themself": "herself", "plural": false},
	"he": {"they": "he", "them": "him", "their": "his", "theirs": "his", "themself": "himself", "plural": false},
	"they": {"they": "they", "them": "them", "their": "their", "theirs": "theirs", "themself": "themself",
		"plural": true},
	"it": {"they": "it", "them": "it", "their": "its", "theirs": "its", "themself": "itself", "plural": false},
}
const FORMS := ["they", "them", "their", "theirs", "themself"]

static var _token := RegEx.create_from_string("\\{([^{}|]+)(?:\\|([^{}]*))?\\}")


## A pronoun set from a preset key ("she", "he", "they", "it") or a custom dictionary with the
## five forms and a "plural" flag.
static func resolve(p: Variant) -> Dictionary:
	if p is Dictionary:
		for f in FORMS:
			assert(p.has(f), "custom pronouns missing '%s'" % f)
		return p
	assert(SETS.has(p), "unknown pronoun set '%s'" % p)
	return SETS[p]


static func fill(text: String, name: String, pronouns: Dictionary) -> String:
	var out := ""
	var at := 0
	for m in _token.search_all(text):
		out += text.substr(at, m.get_start() - at)
		out += _replace(m, name, pronouns)
		at = m.get_end()
	return out + text.substr(at)


static func _replace(m: RegExMatch, name: String, pronouns: Dictionary) -> String:
	var key := m.get_string(1)
	if m.get_string().contains("|"):
		return m.get_string(2) if pronouns.plural else key
	if key == "name":
		return name
	var lower := key.to_lower()
	assert(lower in FORMS, "unknown token {%s}" % key)
	var word: String = pronouns[lower]
	return word[0].to_upper() + word.substr(1) if key[0] != lower[0] else word
