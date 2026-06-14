class_name PlayerDeck
extends Node

signal deck_changed(cards_remaining: int)

var deck: Array[CardData] = []

const SAMPLE_UNIT_CARDS: Array[CardData] = [
	preload("res://cards/definitions/arch_wizard_maelcor.tres"),
	preload("res://cards/definitions/imperial_archive_master.tres"),
	preload("res://cards/definitions/jena_of_yel.tres"),
	preload("res://cards/definitions/ivaan_bone_crusher.tres"),
	preload("res://cards/definitions/upper_hall_prospector.tres"),
]

const SAMPLE_TRIBUTE_TEST_CARDS: Array[CardData] = [
	preload("res://cards/definitions/Test_Equipment.tres"),
	preload("res://cards/definitions/Test_Spell.tres"),
]


func _ready() -> void:
	build_test_deck()


func build_test_deck() -> void:
	deck.clear()

	# 30 unit cards.
	for n in range(6):
		deck.append_array(SAMPLE_UNIT_CARDS)

	# 10 tribute test cards.
	# Test Equipment = permanent tribute test.
	# Test Spell = temporary tribute test.
	for n in range(5):
		deck.append_array(SAMPLE_TRIBUTE_TEST_CARDS)

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
