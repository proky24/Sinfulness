class_name ArmorData extends ItemData
## One armor piece. Unique: the inventory holds at most one of each.

enum Slot { HELMET, CHESTPLATE, GAUNTLETS, BOOTS }
enum ArmorSet { SAINTED, DECAYED }

@export var slot: Slot = Slot.HELMET
@export var armor_set: ArmorSet = ArmorSet.SAINTED

@export_group("Stat modifiers")
@export var health: float = 0.0
@export var damage: float = 0.0
@export var durability: float = 0.0
@export var corruption_durability: float = 0.0
@export var disgrace: float = 0.0
@export var corruption_gain: float = 0.0

@export_group("Equip load")
@export var stance: float = 0.0
@export var dash_distance_modifier: float = 0.0
@export var attack_speed_modifier: float = 0.0


func _init() -> void:
	category = Category.ARMOR


func get_max_stack() -> int:
	return 1
