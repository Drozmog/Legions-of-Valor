class_name PlayerDeck
extends Node

signal deck_changed(cards_remaining: int)

const SAVE_PATH := "user://lov_player_deck.json"
const FALLBACK_DECK_SIZE := 40
const MIN_SAVED_DECK_SIZE := 10

var deck: Array[CardData] = []


func _ready() -> void:
	build_test_deck()


func build_test_deck() -> void:
	deck.clear()

	if load_saved_deck():
		deck.shuffle()
		deck_changed.emit(deck.size())
		return

	build_fallback_deck()
	deck.shuffle()
	deck_changed.emit(deck.size())


func load_saved_deck() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var pool: Array[CardData] = CardDatabase.get_player_test_deck()
	var lookup: Dictionary = {}

	for card in pool:
		var key := get_card_key(card)
		if key != "":
			lookup[key] = card

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false

	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		return false

	var card_ids: Array = (parsed as Dictionary).get("cards", [])
	if card_ids.size() < MIN_SAVED_DECK_SIZE:
		return false

	for raw_id in card_ids:
		var key := String(raw_id)
		if lookup.has(key):
			deck.append(lookup[key])

	return deck.size() >= MIN_SAVED_DECK_SIZE


func build_fallback_deck() -> void:
	var pool: Array[CardData] = CardDatabase.get_player_test_deck()

	if pool.is_empty():
		push_error("PlayerDeck could not build deck because CardDatabase.get_player_test_deck() is empty.")
		return

	var shuffled_pool: Array[CardData] = pool.duplicate()
	shuffled_pool.shuffle()

	if shuffled_pool.size() >= FALLBACK_DECK_SIZE:
		for i in range(FALLBACK_DECK_SIZE):
			deck.append(shuffled_pool[i])
		return

	while deck.size() < FALLBACK_DECK_SIZE:
		var refill: Array[CardData] = pool.duplicate()
		refill.shuffle()
		for card_data in refill:
			if deck.size() >= FALLBACK_DECK_SIZE:
				break
			deck.append(card_data)


func get_card_key(card_data: CardData) -> String:
	if card_data == null:
		return ""
	if card_data.card_id.strip_edges() != "":
		return card_data.card_id.strip_edges()
	return card_data.card_name.to_lower().strip_edges().replace(" ", "_")


func is_empty() -> bool:
	return deck.is_empty()


func cards_remaining() -> int:
	return deck.size()


func peek_top_card() -> CardData:
	if deck.is_empty():
		return null
	return deck[deck.size() - 1]


func draw_top_card() -> CardData:
	if deck.is_empty():
		deck_changed.emit(0)
		return null

	var drawn_card: CardData = deck.pop_back()
	deck_changed.emit(deck.size())
	return drawn_card
