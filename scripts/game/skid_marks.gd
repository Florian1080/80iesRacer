class_name SkidMarks
extends Node2D
## Zeichnet Bremsspuren der Hinterräder, solange ein Auto rutscht.
## Liegt in der Szene zwischen Strecke und Autos, damit die Spuren auf dem Asphalt erscheinen.

const MAX_LINES := 80
const MIN_STEP := 6.0

@export var mark_color := Color(0.09, 0.09, 0.08, 0.5)
@export var mark_width := 6.0

var _cars: Array[Car] = []
var _active := {}


func track_car(car: Car) -> void:
	_cars.append(car)


func _physics_process(_delta: float) -> void:
	for car in _cars:
		if car.is_sliding() and not car.on_grass:
			_extend(car)
		else:
			_active.erase(car)


func _extend(car: Car) -> void:
	var wheels := car.get_rear_wheels()
	var lines: Array = _active.get(car, [])
	if lines.is_empty():
		for wheel in wheels:
			lines.append(_new_line())
		_active[car] = lines
	for i in wheels.size():
		var line: Line2D = lines[i]
		var count := line.get_point_count()
		if count == 0 or line.get_point_position(count - 1).distance_to(wheels[i]) >= MIN_STEP:
			line.add_point(wheels[i])


func _new_line() -> Line2D:
	var line := Line2D.new()
	line.width = mark_width
	line.default_color = mark_color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	add_child(line)
	while get_child_count() > MAX_LINES:
		get_child(0).free()
	return line
