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

	# Prototype deck rule:
	# Build a 40-card deck from the full CardDatabase pool.
	# The old version used pool[i % pool.size()], which means if the pool had more than 40 cards,
	# anything after the first 40 could never appear in the player deck.
	# This version shuffles the full pool first, then takes 40, so every database card has a chance.
	var shuffled_pool: Array[CardData] = pool.duplicate()
	shuffled_pool.shuffle()

	if shuffled_pool.size() >= 40:
		for i in range(40):
			deck.append(shuffled_pool[i])
	else:
		# If the pool is smaller than 40, repeat shuffled copies until the deck reaches 40.
		while deck.size() < 40:
			var refill: Array[CardData] = pool.duplicate()
			refill.shuffle()

			for card_data in refill:
				if deck.size() >= 40:
					break
				deck.append(card_data)

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
