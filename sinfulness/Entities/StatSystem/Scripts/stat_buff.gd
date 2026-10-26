class_name StatBuff extends Resource

enum BuffType {
    ADD, 
    MULTIPLY
}

@export var stat: Stats.BuffableStats
@export var buff_type: BuffType
@export var buff_amount: float

func _init(_stat: Stats.BuffableStats = Stats.BuffableStats.MAX_HEALTH, _buff_type: BuffType = BuffType.MULTIPLY, _buff_amount: float = 1.0) -> void:
    stat = _stat
    buff_type = _buff_type
    buff_amount = _buff_amount
    pass