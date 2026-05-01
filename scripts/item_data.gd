class_name ItemData
extends Resource

enum Type { WEAPON, OFFHAND, HEAD, CHEST, LEGS, FEET, HANDS, RING, NECK, CONSUMABLE, MISC, AUGMENT }
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
# Weapon skill trained by this weapon (e.g. "1h_slashing", "piercing"). See WeaponSkillDefinitions.ALL.
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

# Economy
@export var vendor_price: int = 0  # buy price; sell = vendor_price / 2
