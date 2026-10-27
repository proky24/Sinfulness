class_name StatBuff extends Resource
## A change to one stat. All ADD buffs are applied first, then all MULTIPLY buffs.

enum BuffType { ADD, MULTIPLY }

@export var stat: Stats.Stat = Stats.Stat.MAX_HEALTH
@export var buff_type: BuffType = BuffType.ADD
## ADD: flat amount. MULTIPLY: factor, 1.25 = +25 %.
@export var amount: float = 0.0

## Set by Stats.add_buffs(). Buffs with the same source are replaced and removed together.
var source: StringName = &""


func _init(_stat: Stats.Stat = Stats.Stat.MAX_HEALTH, _buff_type: BuffType = BuffType.ADD, _amount: float = 0.0) -> void:
	stat = _stat
	buff_type = _buff_type
	amount = _amount
