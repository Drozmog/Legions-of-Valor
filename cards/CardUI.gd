class_name CardUI
extends Panel

@onready var name_label: Label = $NameLabel

var card_data: CardData

func setup(data: CardData) -> void:
	card_data = data
	name_label.text = data.card_name
