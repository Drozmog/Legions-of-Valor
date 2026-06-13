class_name PlayerDeck
extends Node

signal deck_changed(cards_remaining: int)

var deck: Array[CardData] = []

const SAMPLE_CARDS: Array[CardData] = [
	preload("res://cards/definitions/Dwarf_Axe_Guard.tres"),
	preload("res://cards/definitions/Elf_Canopy_Archer.tres"),
	preload("res://cards/definitions/Orc_Blood_Raider.tres"),
	preload("res://cards/definitions/Test_Spell.tres"),
	preload("res://cards/definitions/Test_Equipment.tres"),
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
