class_name Marshal
extends Node2D
## Streckenposten in orangefarbener Weste, der eine Flagge schwenkt.
## Steht neben der Strecke und schaut zur Fahrbahn (lokale x-Achse).

@export var flag_color := Color("e0b52a")

var _time := 0.0


func _ready() -> void:
	_time = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Kleines Postenhäuschen
	draw_rect(Rect2(-34, -26, 30, 52), Color("8c8577"))
	draw_rect(Rect2(-32, -24, 26, 48), Color("e3ddcf"))
	draw_rect(Rect2(-32, -24, 26, 8), Color("b8372b"))
	# Posten: Schultern in Weste, Kopf
	draw_circle(Vector2(8, 0), 11.0, Color("d9672a"))
	draw_circle(Vector2(8, 0), 6.0, Color("e8c49a"))
	# Flagge an der Stange, schwenkt hin und her
	var swing := sin(_time * 5.0) * 0.6
	var pole_end := Vector2(8, 0) + Vector2(30, 0).rotated(swing - 0.4)
	draw_line(Vector2(12, 4), pole_end, Color("3a3a36"), 3.0)
	var along := (pole_end - Vector2(12, 4)).normalized()
	var across := along.orthogonal()
	var wave := sin(_time * 9.0) * 4.0
	var flag := PackedVector2Array(
		[
			pole_end,
			pole_end - along * 18.0 + across * wave,
			pole_end - along * 18.0 + across * (16.0 + wave),
			pole_end + across * 16.0,
		]
	)
	draw_colored_polygon(flag, flag_color)
