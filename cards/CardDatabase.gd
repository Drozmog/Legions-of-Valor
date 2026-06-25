class_name CardDatabase
extends RefCounted

const DEFINITIONS_PATH := "res://cards/definitions"

static var _all_cards: Array[CardData] = []
static var _cards_by_id: Dictionary = {}
static var _cache_built := false


# =========================
# UNITS - HUMAN
# =========================

const ARCH_WIZARD_MAELCOR: CardData = preload("res://cards/definitions/unit/human/arch_wizard_maelcor.tres")
const IMPERIAL_ARCHIVE_MASTER: CardData = preload("res://cards/definitions/unit/human/imperial_archive_master.tres")


# =========================
# UNITS - ELF
# =========================


const ARADIN_NOX: CardData = preload("res://cards/definitions/unit/elf/aradin_nox.tres")
const BOUND_BEHEMOTH_BARSAM: CardData = preload("res://cards/definitions/unit/elf/bound_behemoth_barsam.tres")
const CANOPY_ARCHER: CardData = preload("res://cards/definitions/unit/elf/canopy_archer.tres")
const FAELOR_ROYAL_MESSENGER: CardData = preload("res://cards/definitions/unit/elf/faelor_royal_messenger.tres")
const FOREST_OAKLING_ZIRALTAN: CardData = preload("res://cards/definitions/unit/elf/forest_oakling_ziraltan.tres")
const HERAL_THE_SAVIOR: CardData = preload("res://cards/definitions/unit/elf/heral_the_savior.tres")
const HIGH_CANOPY_DUELIST_MIDRA: CardData = preload("res://cards/definitions/unit/elf/high_canopy_duelist_midra.tres")
const INSHI_AZURE_SENTINEL: CardData = preload("res://cards/definitions/unit/elf/inshi_azure_sentinel.tres")
const JENA_OF_YEL: CardData = preload("res://cards/definitions/unit/elf/jena_of_yel.tres")
const KASHA_VAELORI_BLADEWEAVER: CardData = preload("res://cards/definitions/unit/elf/kasha_vaelori_bladeweaver.tres")
const LIORVYNN_GUARDIAN: CardData = preload("res://cards/definitions/unit/elf/liorvynn_guardian.tres")
const LIORVYNN_SENTRY: CardData = preload("res://cards/definitions/unit/elf/liorvynn_sentry.tres")
const LUNARETH_SEER_FLORIN: CardData = preload("res://cards/definitions/unit/elf/lunareth_seer_florin.tres")
const MOON_VEIL_ASSASSIN: CardData = preload("res://cards/definitions/unit/elf/moon_veil_assassin.tres")
const NERIL_VEILMOTHER_HUNTRESS: CardData = preload("res://cards/definitions/unit/elf/neril_veilmother_huntress.tres")
const QUEEN_VARIEL_OF_LIORVYNN: CardData = preload("res://cards/definitions/unit/elf/queen_variel_of_liorvynn.tres")
const SYLVREN_SAPLING: CardData = preload("res://cards/definitions/unit/elf/sylvren_sapling.tres")
const THRAAL_WATCHER: CardData = preload("res://cards/definitions/unit/elf/thraal_watcher.tres")
const TIRAEL_CALITH_GUARD: CardData = preload("res://cards/definitions/unit/elf/tirael_calith_guard.tres")
const ULVITH_THE_MISTBORNE_STALKER: CardData = preload("res://cards/definitions/unit/elf/ulvith_the_mistborne_stalker.tres")
const VAELORI_MIST_SEER: CardData = preload("res://cards/definitions/unit/elf/vaelori_mist_seer.tres")
const VAELORI_SCOUT: CardData = preload("res://cards/definitions/unit/elf/vaelori_scout.tres")
const VARIELS_CHOSEN_RISAK: CardData = preload("res://cards/definitions/unit/elf/variels_chosen_risak.tres")
const WIND_SINGER_HUNWE: CardData = preload("res://cards/definitions/unit/elf/wind_singer_hunwe.tres")


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
const ELITE_MARAUDER_MUURGUL: CardData = preload("res://cards/definitions/unit/orc/elite_marauder_muurgul.tres")
const GERSHAW_SHATTER_SHIELD: CardData = preload("res://cards/definitions/unit/orc/gershaw_shatter_shield.tres")
const GORTHAK_THE_BUTCHER: CardData = preload("res://cards/definitions/unit/orc/gorthak_the_butcher.tres")
const HIGH_CHIEFTAIN_GROG: CardData = preload("res://cards/definitions/unit/orc/high_chieftain_grog.tres")
const IRONHOLD_RAIDER: CardData = preload("res://cards/definitions/unit/orc/ironhold_raider.tres")
const IVAAN_THE_BONE_CRUSHER: CardData = preload("res://cards/definitions/unit/orc/ivaan_the_bone_crusher.tres")
const KRELL_THE_BLOODLET: CardData = preload("res://cards/definitions/unit/orc/krell_the_bloodlet.tres")
const ORCISH_MILITIA: CardData = preload("res://cards/definitions/unit/orc/orcish_militia.tres")
const ORKHAEL_OUTCAST: CardData = preload("res://cards/definitions/unit/orc/orkhael_outcast.tres")
const ORKHAEL_SCAVENGER: CardData = preload("res://cards/definitions/unit/orc/orkhael_scavenger.tres")
const ORKHAEL_WARLORD_RIUYO: CardData = preload("res://cards/definitions/unit/orc/orkhael_warlord_riuyo.tres")
const RAGING_ORKHAEL_VLARA: CardData = preload("res://cards/definitions/unit/orc/raging_orkhael_vlara.tres")
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
	return get_cards_by_race("human")


static func get_all_elf_cards() -> Array[CardData]:
	return get_cards_by_race("elf")


static func get_all_dwarf_cards() -> Array[CardData]:
	return get_cards_by_race("dwarf")


static func get_all_orc_cards() -> Array[CardData]:
	return get_cards_by_race("orc")


static func get_all_unit_cards() -> Array[CardData]:
	return get_cards_by_type("unit")


static func get_all_equipment_cards() -> Array[CardData]:
	return get_cards_by_type("equipment")


static func get_all_gambit_cards() -> Array[CardData]:
	return get_cards_by_type("gambit")


static func get_all_test_cards() -> Array[CardData]:
	return get_all_cards()


static func get_player_test_deck() -> Array[CardData]:
	return get_all_test_cards()


static func get_ai_test_deck() -> Array[CardData]:
	return get_all_test_cards()


static func get_all_cards() -> Array[CardData]:
	_ensure_cache()
	return _all_cards.duplicate()


static func get_card_by_id(card_id: String) -> CardData:
	_ensure_cache()
	return _cards_by_id.get(card_id.strip_edges().to_lower()) as CardData


static func get_cards_by_race(race: String) -> Array[CardData]:
	var wanted := race.strip_edges().to_lower()
	var result: Array[CardData] = []
	for card in get_all_cards():
		if card.race.strip_edges().to_lower() == wanted:
			result.append(card)
	return result


static func get_cards_by_type(card_type: String) -> Array[CardData]:
	var wanted := card_type.strip_edges().to_lower()
	var result: Array[CardData] = []
	for card in get_all_cards():
		if card.card_type.strip_edges().to_lower() == wanted:
			result.append(card)
	return result


static func reload() -> void:
	_cache_built = false
	_all_cards.clear()
	_cards_by_id.clear()
	_ensure_cache()


static func _ensure_cache() -> void:
	if _cache_built:
		return
	_cache_built = true
	_collect_cards(DEFINITIONS_PATH)
	_all_cards.sort_custom(func(a: CardData, b: CardData) -> bool:
		return a.card_name.naturalnocasecmp_to(b.card_name) < 0
	)


static func _collect_cards(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		push_error("CardDatabase could not open " + path)
		return

	directory.list_dir_begin()
	var entry_name := directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			var entry_path := path.path_join(entry_name)
			if directory.current_is_dir():
				_collect_cards(entry_path)
			elif entry_name.get_extension().to_lower() == "tres":
				_register_card(entry_path)
		entry_name = directory.get_next()
	directory.list_dir_end()


static func _register_card(path: String) -> void:
	var resource := ResourceLoader.load(path)
	if not resource is CardData:
		return
	var card := resource as CardData
	if not card.is_valid():
		push_warning("Ignoring invalid CardData: " + path)
		return
	var key := card.card_id.strip_edges().to_lower()
	if _cards_by_id.has(key):
		push_error("Duplicate card_id '%s' in %s" % [card.card_id, path])
		return
	_cards_by_id[key] = card
	_all_cards.append(card)
