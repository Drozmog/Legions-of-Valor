class_name PlayerDeck
extends Node

signal deck_changed(cards_remaining: int)

var deck: Array[CardData] = []


func _ready() -> void:
	build_test_deck()


func build_test_deck() -> void:
	deck.clear()

	var pool: Array[CardData] = CardDatabase.get_player_test_deck()

	if pool.is_empty():
		push_error("PlayerDeck could not build deck because CardDatabase.get_player_test_deck() is empty.")
		deck_changed.emit(0)
		return

	# Temporary prototype deck: repeat the available cards until we have 40.
	for i in range(40):
		deck.append(pool[i % pool.size()])

	deck.shuffle()
	deck_changed.emit(deck.size())


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
