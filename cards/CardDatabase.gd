class_name CardDatabase
extends RefCounted


# =========================
# UNITS - HUMAN
# =========================

const ARCH_WIZARD_MAELCOR: CardData = preload("res://cards/definitions/unit/human/arch_wizard_maelcor.tres")
const IMPERIAL_ARCHIVE_MASTER: CardData = preload("res://cards/definitions/unit/human/imperial_archive_master.tres")


# =========================
# UNITS - ELF
# =========================

const JENA_OF_YEL: CardData = preload("res://cards/definitions/unit/elf/jena_of_yel.tres")
const SYLVREN_SAPLING: CardData = preload("res://cards/definitions/unit/elf/sylvren_sapling.tres")


# =========================
# UNITS - DWARF
# =========================

const ARCHITECT_OF_THE_DEEP: CardData = preload("res://cards/definitions/unit/dwarf/architect_of_the_deep.tres")
const UPPER_HALL_PROSPECTOR: CardData = preload("res://cards/definitions/unit/dwarf/upper_hall_prospector.tres")


# =========================
# UNITS - ORC
# =========================

const IVAAN_THE_BONE_CRUSHER: CardData = preload("res://cards/definitions/unit/orc/ivaan_the_bone_crusher.tres")
const ORKHAEL_OUTCAST: CardData = preload("res://cards/definitions/unit/orc/orkhael_outcast.tres")


# =========================
# EQUIPMENT
# =========================

const GRAVE_CROSSERS_PACK_A: CardData = preload("res://cards/definitions/equipment/grave_crossers_pack_a.tres")
const VAELORI_LONGBOW_M: CardData = preload("res://cards/definitions/equipment/vaelori_longbow_m.tres")


# =========================
# GAMBITS
# =========================

const BLACKMAIL: CardData = preload("res://cards/definitions/gambit/blackmail.tres")
const WITHERING_OF_THE_VEIL: CardData = preload("res://cards/definitions/gambit/withering_of_the_veil.tres")


# =========================
# CARD POOLS
# =========================

static func get_all_test_cards() -> Array[CardData]:
	return [
		ARCH_WIZARD_MAELCOR,
		IMPERIAL_ARCHIVE_MASTER,
		JENA_OF_YEL,
		SYLVREN_SAPLING,
		ARCHITECT_OF_THE_DEEP,
		UPPER_HALL_PROSPECTOR,
		IVAAN_THE_BONE_CRUSHER,
		ORKHAEL_OUTCAST,
		GRAVE_CROSSERS_PACK_A,
		VAELORI_LONGBOW_M,
		BLACKMAIL,
		WITHERING_OF_THE_VEIL,
	]


static func get_player_test_deck() -> Array[CardData]:
	return get_all_test_cards()


static func get_ai_test_deck() -> Array[CardData]:
	return get_all_test_cards()
