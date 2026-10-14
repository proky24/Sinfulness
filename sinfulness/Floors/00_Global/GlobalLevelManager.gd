extends Node

var curr_tilemap_bounds: Array[Vector2]
signal tilemap_bounds_changed( bounds: Array[Vector2] )

func change_tilemap_bounds(bounds: Array[Vector2]) -> void:
	curr_tilemap_bounds = bounds
	tilemap_bounds_changed.emit()
	pass 
