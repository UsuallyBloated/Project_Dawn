class_name ItemData
extends Resource

enum Type { WEAPON, OFFHAND, HEAD, CHEST, LEGS, FEET, HANDS, RING, NECK, CONSUMABLE, MISC }
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
