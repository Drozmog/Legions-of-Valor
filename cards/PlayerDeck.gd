class_name PlayerDeck
extends Node

signal deck_changed(cards_remaining: int)

var deck: Array[CardData] = []

const SAMPLE_CARDS: Array[CardData] = [
	preload("res://cards/definitions/Arch_Wizard_Maelcor.tres"),
	preload("res://cards/definitions/Imperial_Archive_Master.tres"),
	preload("res://cards/definitions/Jena_of_Yel.tres"),
	preload("res://cards/definitions/Ivaan_Bone_Crusher.tres"),
	preload("res://cards/definitions/Upper_Hall_Prospector.tres"),
]


func _ready() -> void:
	build_test_deck()


func build_test_deck() -> void:
	deck.clear()

	for n in range(8):
		deck.append_array(SAMPLE_CARDS)

	deck.shuffle()
	deck_changed.emit(deck.size())


func is_empty() -> bool:
	return deck.is_empty()


func cards_remaining() -> int:
	return deck.size()


func peek_top_card() -> CardData:
	if deck.is_empty():
		return null

	return deck.back()


func draw_top_card() -> CardData:
	if deck.is_empty():
		return null

	var card_data: CardData = deck.pop_back()
	deck_changed.emit(deck.size())

	return card_data
