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

const BRUGO_THE_BOLD: CardData = preload("res://cards/definitions/unit/orc/brugo_the_bold.tres")
const CAVE_CRAWL_GRUNT: CardData = preload("res://cards/definitions/unit/orc/cave_crawl_grunt.tres")
const DREAD_PIT_BRAWLER: CardData = preload("res://cards/definitions/unit/orc/dread_pit_brawler.tres")
const ELITE_MARAUDER: CardData = preload("res://cards/definitions/unit/orc/elite_marauder.tres")
const GERSHAW_SHATTER_SHIELD: CardData = preload("res://cards/definitions/unit/orc/gershaw_shatter_shield.tres")
const GORTHAK_THE_BUTCHER: CardData = preload("res://cards/definitions/unit/orc/gorthak_the_butcher.tres")
const HIGH_CHIEFTAIN_GROG: CardData = preload("res://cards/definitions/unit/orc/high_chieftain_grog.tres")
const IRONHOLD_RAIDER: CardData = preload("res://cards/definitions/unit/orc/ironhold_raider.tres")
const IVAAN_THE_BONE_CRUSHER: CardData = preload("res://cards/definitions/unit/orc/ivaan_the_bone_crusher.tres")
const KRELL_THE_BLOODLET: CardData = preload("res://cards/definitions/unit/orc/krell_the_bloodlet.tres")
const ORCISH_MILITIA: CardData = preload("res://cards/definitions/unit/orc/orcish_militia.tres")
const ORKHAEL_OUTCAST: CardData = preload("res://cards/definitions/unit/orc/orkhael_outcast.tres")
const ORKHAEL_SCAVENGER: CardData = preload("res://cards/definitions/unit/orc/orkhael_scavenger.tres")
const ORKHAEL_WARLORD: CardData = preload("res://cards/definitions/unit/orc/orkhael_warlord.tres")
const RAGING_ORKHAEL: CardData = preload("res://cards/definitions/unit/orc/raging_orkhael.tres")
const SIEGE_BREAKER_ORC: CardData = preload("res://cards/definitions/unit/orc/siege_breaker_orc.tres")
const SLAUGHTER_VETERAN_VIGO: CardData = preload("res://cards/definitions/unit/orc/slaughter_veteran_vigo.tres")
const SOLKARAN_DEPTH_DWELLER: CardData = preload("res://cards/definitions/unit/orc/solkaran_depth_dweller.tres")
const THRAK_PIT_LORD: CardData = preload("res://cards/definitions/unit/orc/thrak_pit_lord.tres")
const URMOG_BRUGOS_CHOSEN: CardData = preload("res://cards/definitions/unit/orc/urmog_brugos_chosen.tres")
const VANGUARD_MAULER: CardData = preload("res://cards/definitions/unit/orc/vanguard_mauler.tres")
const VARK_THE_MANGLER: CardData = preload("res://cards/definitions/unit/orc/vark_the_mangler.tres")
const ZARKHAN_THE_PRIMEVAL: CardData = preload("res://cards/definitions/unit/orc/zarkhan_the_primeval.tres")


# =========================
# EQUIPMENT
# =========================

const BANNER_OF_EXPEDITION: CardData = preload("res://cards/definitions/equipment/banner_of_expedition.tres")
const BRACERS_OF_THE_DEPTH: CardData = preload("res://cards/definitions/equipment/bracers_of_the_depth.tres")
const CLOAK_OF_SECRECY: CardData = preload("res://cards/definitions/equipment/cloak_of_secrecy.tres")
const DALMIRS_TOME: CardData = preload("res://cards/definitions/equipment/dalmirs_tome.tres")
const ELYNDELLS_LEATHER_CUIRASS: CardData = preload("res://cards/definitions/equipment/elyndells_leather_cuirass.tres")
const GRAVE_CROSSERS_PACK: CardData = preload("res://cards/definitions/equipment/grave_crossers_pack.tres")
const VAELORI_LONGBOW: CardData = preload("res://cards/definitions/equipment/vaelori_longbow.tres")


# =========================
# GAMBITS
# =========================

const BLACKMAIL: CardData = preload("res://cards/definitions/gambit/blackmail.tres")
const CONSORTIUM_AID: CardData = preload("res://cards/definitions/gambit/consortium_aid.tres")
const ELYNDELL_ARROW_VOLLEY: CardData = preload("res://cards/definitions/gambit/elyndell_arrow_volley.tres")
const FOG_OF_WAR: CardData = preload("res://cards/definitions/gambit/fog_of_war.tres")
const GRIDLOCK: CardData = preload("res://cards/definitions/gambit/gridlock.tres")
const PICKPOCKET: CardData = preload("res://cards/definitions/gambit/pickpocket.tres")
const PLENTIFUL_HARVEST: CardData = preload("res://cards/definitions/gambit/plentiful_harvest.tres")
const SOUL_SALVAGE: CardData = preload("res://cards/definitions/gambit/soul_salvage.tres")
const THE_DIE_IS_CAST: CardData = preload("res://cards/definitions/gambit/the_die_is_cast.tres")
const TRANSMUTATION: CardData = preload("res://cards/definitions/gambit/transmutation.tres")
const WAR_PAINT: CardData = preload("res://cards/definitions/gambit/war_paint.tres")
const FREE_TAXI_SERVICE: CardData = preload("res://cards/definitions/gambit/free_taxi_service.tres")
const WITHERING_OF_THE_VEIL: CardData = preload("res://cards/definitions/gambit/withering_of_the_veil.tres")


# =========================
# CARD POOLS
# =========================

static func get_all_human_cards() -> Array[CardData]:
	return [
		ARCH_WIZARD_MAELCOR,
		IMPERIAL_ARCHIVE_MASTER,
	]


static func get_all_elf_cards() -> Array[CardData]:
	return [
		JENA_OF_YEL,
		SYLVREN_SAPLING,
	]


static func get_all_dwarf_cards() -> Array[CardData]:
	return [
		ARCHITECT_OF_THE_DEEP,
		UPPER_HALL_PROSPECTOR,
	]


static func get_all_orc_cards() -> Array[CardData]:
	return [
		BRUGO_THE_BOLD,
		CAVE_CRAWL_GRUNT,
		DREAD_PIT_BRAWLER,
		ELITE_MARAUDER,
		GERSHAW_SHATTER_SHIELD,
		GORTHAK_THE_BUTCHER,
		HIGH_CHIEFTAIN_GROG,
		IRONHOLD_RAIDER,
		IVAAN_THE_BONE_CRUSHER,
		KRELL_THE_BLOODLET,
		ORCISH_MILITIA,
		ORKHAEL_OUTCAST,
		ORKHAEL_SCAVENGER,
		ORKHAEL_WARLORD,
		RAGING_ORKHAEL,
		SIEGE_BREAKER_ORC,
		SLAUGHTER_VETERAN_VIGO,
		SOLKARAN_DEPTH_DWELLER,
		THRAK_PIT_LORD,
		URMOG_BRUGOS_CHOSEN,
		VANGUARD_MAULER,
		VARK_THE_MANGLER,
		ZARKHAN_THE_PRIMEVAL,
	]


static func get_all_unit_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	cards.append_array(get_all_human_cards())
	cards.append_array(get_all_elf_cards())
	cards.append_array(get_all_dwarf_cards())
	cards.append_array(get_all_orc_cards())
	return cards


static func get_all_equipment_cards() -> Array[CardData]:
	return [
		BANNER_OF_EXPEDITION,
		BRACERS_OF_THE_DEPTH,
		CLOAK_OF_SECRECY,
		DALMIRS_TOME,
		ELYNDELLS_LEATHER_CUIRASS,
		GRAVE_CROSSERS_PACK,
		VAELORI_LONGBOW,
	]


static func get_all_gambit_cards() -> Array[CardData]:
	return [
		BLACKMAIL,
		CONSORTIUM_AID,
		ELYNDELL_ARROW_VOLLEY,
		FOG_OF_WAR,
		FREE_TAXI_SERVICE,
		GRIDLOCK,
		PICKPOCKET,
		PLENTIFUL_HARVEST,
		SOUL_SALVAGE,
		THE_DIE_IS_CAST,
		TRANSMUTATION,
		WAR_PAINT,
		WITHERING_OF_THE_VEIL,
	]


static func get_all_test_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	cards.append_array(get_all_unit_cards())
	cards.append_array(get_all_equipment_cards())
	cards.append_array(get_all_gambit_cards())
	return cards


static func get_player_test_deck() -> Array[CardData]:
	return get_all_test_cards()


static func get_ai_test_deck() -> Array[CardData]:
	return get_all_test_cards()
