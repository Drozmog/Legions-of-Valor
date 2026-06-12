extends Resource
class_name CardData

@export var card_id: String = ""
@export var card_name: String = ""

@export var race: String = ""
@export var card_type: String = "" # unit, ruse, trap, spell, equipment
@export var rarity: String = "" # common, rare, elite

@export var mana_cost: int = 0
@export var ap: int = 0
@export var dp: int = 0

@export_multiline var ability_text: String = ""
@export var card_art: Texture2D
