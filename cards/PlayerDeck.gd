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
	var data := read_saved_deck_data()
	if data.is_empty():
		return false
	var loaded := false
	if data.has("decks") and data["decks"] is Array:
		var saved_slots: Array = data["decks"]
		if saved_slots.is_empty():
			return false
		var active_slot := clampi(int(data.get("active_slot", 0)), 0, saved_slots.size() - 1)
		loaded = load_card_ids_from_slot(saved_slots[active_slot])
	else:
		loaded = load_card_ids_from_slot(data)
	if not loaded:
		deck.clear()
	return loaded


func load_saved_deck_slot(slot_index: int, shuffle_after_load: bool = true) -> bool:
	var data := read_saved_deck_data()
	if data.is_empty():
		return false
	var slot_data: Dictionary = {}
	if data.has("decks") and data["decks"] is Array:
		var saved_slots: Array = data["decks"]
		if slot_index < 0 or slot_index >= saved_slots.size() or not saved_slots[slot_index] is Dictionary:
			return false
		slot_data = saved_slots[slot_index]
	elif slot_index == 0:
		slot_data = data
	else:
		return false

	deck.clear()
	if not load_card_ids_from_slot(slot_data):
		deck.clear()
		return false
	if shuffle_after_load:
		deck.shuffle()
	deck_changed.emit(deck.size())
	return true


func use_fallback_deck() -> void:
	deck.clear()
	build_fallback_deck()
	deck.shuffle()
	deck_changed.emit(deck.size())


func get_saved_deck_summaries() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	var data := read_saved_deck_data()
	if data.is_empty():
		return summaries
	if data.has("decks") and data["decks"] is Array:
		var saved_slots: Array = data["decks"]
		for slot_index in range(saved_slots.size()):
			if not saved_slots[slot_index] is Dictionary:
				continue
			var slot_data: Dictionary = saved_slots[slot_index]
			var card_ids: Array = slot_data.get("cards", [])
			summaries.append({
				"slot_index": slot_index,
				"deck_name": String(slot_data.get("deck_name", "Deck " + str(slot_index + 1))),
				"card_count": card_ids.size(),
				"valid": card_ids.size() >= MIN_SAVED_DECK_SIZE,
			})
		return summaries

	var legacy_cards: Array = data.get("cards", [])
	summaries.append({
		"slot_index": 0,
		"deck_name": String(data.get("deck_name", "Saved Deck")),
		"card_count": legacy_cards.size(),
		"valid": legacy_cards.size() >= MIN_SAVED_DECK_SIZE,
	})
	return summaries


func read_saved_deck_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func load_card_ids_from_slot(slot_data: Dictionary) -> bool:
	var card_ids: Array = slot_data.get("cards", [])
	if card_ids.size() < MIN_SAVED_DECK_SIZE:
		return false
	var lookup: Dictionary = {}
	for card in CardDatabase.get_all_test_cards():
		var key := get_card_key(card)
		if key != "":
			lookup[key] = card
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
