extends Node

## Autoload singleton ("SlipDeck") — supplies the fax slip that prints after
## every filing. Slips are the only thing the game gives back, so they must
## never line up with being right or wrong: they are picked by which drawer
## the paper went into, not by whether the player was correct. Each tray has
## its own shuffled deck, drawn one slip at a time and reshuffled only when
## emptied, so a short run never repeats a line and never falls into a
## pattern a player could read as feedback.

## Lines per drawer. Every deck mixes tones on purpose — at least one
## cheerful line follows a correct filing, one grim line follows a wrong
## one, so nothing the slip says maps onto the score.
const SLIPS := {
	FilingTray.TrayType.PUBLIC_ARCHIVE: [
		"Filed. The subject is grateful.",
		"Filed. You missed a spot. It is too late now.",
		"Filed. Thank you for your care.",
		"Filed. The record is heavier today.",
		"Filed. It was looking at you the whole time.",
		"Filed. We have seen this face before.",
		"Received. No further action is possible.",
		"Received. Your hand was steady.",
		"Received. Keep working.",
	],
	FilingTray.TrayType.DEPARTMENT_OF_TRUTH: [
		"Held. It is still moving.",
		"Held. Someone will come for it.",
		"Held for study. Do not ask what was found.",
		"Received. No further action is possible.",
		"Received. Keep working.",
	],
	FilingTray.TrayType.INCINERATOR: [
		"Burned. We will ignore the screaming.",
		"Burned. Nothing was lost that we will miss.",
		"Burned. The smell will pass.",
	],
}

## The ANY wildcard has no real drawer, so it borrows the Archive pool. The
## paper still went somewhere, and the player should not be able to tell from
## the slip that their choice didn't matter.
const WILDCARD_FALLBACK := FilingTray.TrayType.PUBLIC_ARCHIVE

## tray_type -> remaining slips. A deck is drawn without replacement; when
## empty, refill from SLIPS and reshuffle.
var _decks: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for tray_type in SLIPS:
		_decks[tray_type] = []


## A slip line for the given drawer, without replacement until its pool runs
## out. Call once per filing, in place of — not alongside — any scoring call.
func draw(tray_type: int) -> String:
	var pool: Array = SLIPS.get(tray_type, SLIPS[WILDCARD_FALLBACK])
	var deck: Array = _decks.get(tray_type, [])
	if deck.is_empty():
		deck = pool.duplicate()
		deck.shuffle()
		_decks[tray_type] = deck
	return deck.pop_back()


func reset() -> void:
	for tray_type in _decks:
		_decks[tray_type] = []
