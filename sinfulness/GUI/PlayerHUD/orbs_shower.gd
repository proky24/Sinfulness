extends TextureRect

@onready var orbs_label: Label = $Label

func _update_orbs_display(orbs: int) -> void:
	orbs_label.text = str(orbs)

func _connect_orbs_changed_signal() -> void:
	var global_player_manager = get_node("/root/GlobalPlayerManager") as Node
	if global_player_manager != null:
		global_player_manager.player_stats.orbs_changed.connect(_update_orbs_display)

func _ready() -> void:
	_connect_orbs_changed_signal.call_deferred()
	pass
