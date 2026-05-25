class_name ItemData
extends Resource

enum Type { WEAPON, OFFHAND, HEAD, CHEST, LEGS, FEET, HANDS, RING, NECK, CONSUMABLE, MISC, AUGMENT, BAG }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC }

@export var item_name: String = ""
@export var description: String = ""
@export var type: Type = Type.MISC
@export var rarity: Rarity = Rarity.COMMON
@export var icon: Texture2D = null
@export var stack_size: int = 1

# Stat bonuses applied when equipped
@export var bonus_strength: int = 0
@export var bonus_dexterity: int = 0
@export var bonus_agility: int = 0
@export var bonus_intelligence: int = 0
@export var bonus_wisdom: int = 0
@export var bonus_charisma: int = 0
@export var bonus_constitution: int = 0
@export var bonus_max_hp: float = 0.0
@export var bonus_max_mp: float = 0.0
@export var bonus_max_stamina: float = 0.0

# Weapon stats (weapons only)
@export var weapon_damage_min: int = 0
@export var weapon_damage_max: int = 0
@export var weapon_delay: float = 2.0  # base attack interval in seconds; unaffected by stats
@export var is_two_handed: bool = false
@export var is_ranged: bool = false    # bow/crossbow: uses ranged range, DEX damage bonus, archery skill
# Weapon skill trained by this weapon (e.g. "1h_slashing", "piercing", "archery"). See WeaponSkillDefinitions.ALL.
@export var weapon_skill: String = ""

# Physical damage reduction when equipped (armor pieces)
@export var bonus_armor: int = 0
# Armor skill trained by this item. See ArmorSkillDefinitions.ALL.
# "cloth", "leather", "chain", "plate", "shield" — or "" for non-armor items.
@export var armor_type: String = ""

# Consumable use effects (CONSUMABLE type only)
@export var heal_on_use: float = 0.0
@export var mp_on_use: float = 0.0

@export var is_food: bool = false
@export var is_drink: bool = false
@export var food_hp_regen: float = 0.0
@export var food_mp_regen: float = 0.0
@export var food_duration: float = 0.0

# Augmentation
# gem_slots > 0 means this item can be augmented. socketed_augments holds the
# names of inserted augment items (max gem_slots entries).
@export var gem_slots: int = 0
@export var socketed_augments: Array[String] = []

# Bag (BAG type only)
@export var bag_num_slots: int = 0

# Track 22.C — Mount whistle. Right-clicking an item with is_mount=true
# routes through MountManager.summon: applies the mount speed
# multiplier (which overrides all other speed sources), enters the
# mounted state, dismounts on any incoming damage / death / zone
# entry into a no-mount zone. Whistles are not consumed (single-use
# would feel bad for a travel tool); they remain in inventory.
@export var is_mount: bool = false
@export var mount_speed_mult: float = 1.6   # speed multiplier while mounted
@export var mount_name: String = ""         # display label, e.g. "Brown Steed"

# On-hit proc effect (WEAPON type only). proc_chance 0 = disabled.
@export var proc_chance: float = 0.0         # 0.0–1.0; probability per hit
@export var proc_damage: int = 0             # flat damage on proc fire
@export var proc_damage_type: SpellData.DamageType = SpellData.DamageType.NONE
@export var proc_name: String = ""           # combat log label, e.g. "Flaming Strike"

# Economy
@export var vendor_price: int = 0  # buy price; sell = vendor_price / 2

# ── Save / load (Tier 2) ──────────────────────────────────────────────────────

# Serialize to a dict for JSON. Items loaded from a `.tres` file are saved as
# {"path": ...}; runtime-built items have no path and fall back to a full field
# snapshot. Loader (`from_save_dict`) checks `path` first, then `snapshot`.
func to_save_dict() -> Dictionary:
	var p: String = resource_path
	if p != "" and not p.begins_with("local://"):
		return {"path": p}
	return {"snapshot": _to_snapshot()}

func _to_snapshot() -> Dictionary:
	var icon_path: String = ""
	if icon != null:
		icon_path = icon.resource_path
	return {
		"item_name": item_name, "description": description,
		"type": int(type), "rarity": int(rarity), "icon_path": icon_path,
		"stack_size": stack_size,
		"bonus_strength": bonus_strength, "bonus_dexterity": bonus_dexterity,
		"bonus_agility": bonus_agility, "bonus_intelligence": bonus_intelligence,
		"bonus_wisdom": bonus_wisdom, "bonus_charisma": bonus_charisma,
		"bonus_constitution": bonus_constitution,
		"bonus_max_hp": bonus_max_hp, "bonus_max_mp": bonus_max_mp,
		"bonus_max_stamina": bonus_max_stamina,
		"weapon_damage_min": weapon_damage_min, "weapon_damage_max": weapon_damage_max,
		"weapon_delay": weapon_delay, "is_two_handed": is_two_handed,
		"is_ranged": is_ranged, "weapon_skill": weapon_skill,
		"bonus_armor": bonus_armor, "armor_type": armor_type,
		"heal_on_use": heal_on_use, "mp_on_use": mp_on_use,
		"is_food": is_food, "is_drink": is_drink,
		"food_hp_regen": food_hp_regen, "food_mp_regen": food_mp_regen,
		"food_duration": food_duration,
		"gem_slots": gem_slots, "socketed_augments": socketed_augments.duplicate(),
		"bag_num_slots": bag_num_slots,
		"proc_chance": proc_chance, "proc_damage": proc_damage,
		"proc_damage_type": int(proc_damage_type), "proc_name": proc_name,
		"vendor_price": vendor_price,
	}

static func from_save_dict(d: Dictionary) -> ItemData:
	var p: String = d.get("path", "")
	if p != "":
		var loaded: ItemData = load(p) as ItemData
		if loaded != null:
			return loaded
		push_warning("ItemData.from_save_dict: failed to load resource %s" % p)
	var snap: Dictionary = d.get("snapshot", {})
	if snap.is_empty():
		return null
	var item := ItemData.new()
	item.item_name          = snap.get("item_name", "")
	item.description        = snap.get("description", "")
	item.type               = snap.get("type", Type.MISC)
	item.rarity             = snap.get("rarity", Rarity.COMMON)
	var icon_path: String   = snap.get("icon_path", "")
	if icon_path != "":
		item.icon = load(icon_path) as Texture2D
	item.stack_size         = snap.get("stack_size", 1)
	item.bonus_strength     = snap.get("bonus_strength", 0)
	item.bonus_dexterity    = snap.get("bonus_dexterity", 0)
	item.bonus_agility      = snap.get("bonus_agility", 0)
	item.bonus_intelligence = snap.get("bonus_intelligence", 0)
	item.bonus_wisdom       = snap.get("bonus_wisdom", 0)
	item.bonus_charisma     = snap.get("bonus_charisma", 0)
	item.bonus_constitution = snap.get("bonus_constitution", 0)
	item.bonus_max_hp       = snap.get("bonus_max_hp", 0.0)
	item.bonus_max_mp       = snap.get("bonus_max_mp", 0.0)
	item.bonus_max_stamina  = snap.get("bonus_max_stamina", 0.0)
	item.weapon_damage_min  = snap.get("weapon_damage_min", 0)
	item.weapon_damage_max  = snap.get("weapon_damage_max", 0)
	item.weapon_delay       = snap.get("weapon_delay", 2.0)
	item.is_two_handed      = snap.get("is_two_handed", false)
	item.is_ranged          = snap.get("is_ranged", false)
	item.weapon_skill       = snap.get("weapon_skill", "")
	item.bonus_armor        = snap.get("bonus_armor", 0)
	item.armor_type         = snap.get("armor_type", "")
	item.heal_on_use        = snap.get("heal_on_use", 0.0)
	item.mp_on_use          = snap.get("mp_on_use", 0.0)
	item.is_food            = snap.get("is_food", false)
	item.is_drink           = snap.get("is_drink", false)
	item.food_hp_regen      = snap.get("food_hp_regen", 0.0)
	item.food_mp_regen      = snap.get("food_mp_regen", 0.0)
	item.food_duration      = snap.get("food_duration", 0.0)
	item.gem_slots          = snap.get("gem_slots", 0)
	var augs: Array         = snap.get("socketed_augments", [])
	item.socketed_augments  = []
	for a in augs:
		item.socketed_augments.append(str(a))
	item.bag_num_slots      = snap.get("bag_num_slots", 0)
	item.proc_chance        = snap.get("proc_chance", 0.0)
	item.proc_damage        = snap.get("proc_damage", 0)
	item.proc_damage_type   = snap.get("proc_damage_type", SpellData.DamageType.NONE)
	item.proc_name          = snap.get("proc_name", "")
	item.vendor_price       = snap.get("vendor_price", 0)
	return item
