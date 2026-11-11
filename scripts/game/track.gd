class_name Track
extends Node2D
## Rundkurs, der aus wenigen Stützpunkten erzeugt wird.
##
## Aus den Stützpunkten entsteht eine glatte Mittellinie. Daraus werden Asphalt,
## Randsteine (nur in Kurven), weiße Randlinien, Start-Ziel-Linie, Reifenstapel
## und die Begrenzungsmauern berechnet. Die Mittellinie dient später auch
## den Computer-Gegnern als Ideallinie.

const SAMPLE_SPACING := 24.0
const CURB_MAX_RADIUS := 1100.0

@export var control_points := PackedVector2Array(
	[
		Vector2(-1700, 0),
		Vector2(900, 0),
		Vector2(1900, -200),
		Vector2(2250, -950),
		Vector2(1850, -1750),
		Vector2(900, -1900),
		Vector2(300, -1450),
		Vector2(-300, -1050),
		Vector2(-1000, -1300),
		Vector2(-1800, -1800),
		Vector2(-2650, -1400),
		Vector2(-2800, -600),
	]
)
@export var road_width := 300.0
@export var runoff := 170.0
@export var curb_width := 16.0

@export_group("Farben")
@export var grass_color := Color("5b7a3c")
@export var grass_stripe_color := Color("648343")
@export var asphalt_color := Color("4b4b48")
@export var line_color := Color("e6e0cf")
@export var curb_red := Color("b8372b")
@export var curb_white := Color("ebe5d6")
@export var tyre_color := Color("1e1e1c")

## Geglättete Mittellinie, gleichmäßig verteilt.
var points := PackedVector2Array()

var _normals := PackedVector2Array()
var _curvy := PackedByteArray()
var _outer_wall := PackedVector2Array()
var _inner_wall := PackedVector2Array()


func _ready() -> void:
	points = _resample(_catmull_rom(control_points, 20), SAMPLE_SPACING)
	_normals = _compute_normals(points)
	_curvy = _compute_curvy(points)
	_outer_wall = _offset(road_width * 0.5 + runoff)
	_inner_wall = _offset(-(road_width * 0.5 + runoff))
	_build_walls()
	queue_redraw()


## Liegt die Position auf Asphalt (inklusive Randsteinen)?
func is_on_road(pos: Vector2) -> bool:
	return distance_to_centerline(pos) <= road_width * 0.5 + curb_width


func distance_to_centerline(pos: Vector2) -> float:
	return sqrt(points[nearest_index(pos)].distance_squared_to(pos))


func nearest_index(pos: Vector2) -> int:
	var best := 0
	var best_dist := INF
	for i in points.size():
		var d := points[i].distance_squared_to(pos)
		if d < best_dist:
			best_dist = d
			best = i
	return best


## Startposition: kurz vor der Start-Ziel-Linie, in Fahrtrichtung.
func get_start_transform(grid_slot := 0) -> Transform2D:
	var index := points.size() - 5 - grid_slot * 4
	var tangent := (points[index + 1] - points[index]).normalized()
	var side := 1.0 if grid_slot % 2 == 0 else -1.0
	var pos := points[index] + tangent.orthogonal() * side * road_width * 0.2
	return Transform2D(tangent.angle(), pos)


func _draw() -> void:
	_draw_grass()
	_draw_band(-road_width * 0.5, road_width * 0.5, func(_i: int) -> Color: return asphalt_color)
	_draw_edges()
	_draw_start_line()
	_draw_tyres(_outer_wall)
	_draw_tyres(_inner_wall)


func _draw_grass() -> void:
	var bounds := Rect2(_outer_wall[0], Vector2.ZERO)
	for p in _outer_wall:
		bounds = bounds.expand(p)
	bounds = bounds.grow(1600.0)
	draw_rect(bounds, grass_color)
	var stripe := 140.0
	var x := bounds.position.x
	while x < bounds.end.x:
		draw_rect(Rect2(x, bounds.position.y, stripe, bounds.size.y), grass_stripe_color)
		x += stripe * 2.0


## Zeichnet ein Band entlang der Mittellinie zwischen zwei seitlichen Abständen.
func _draw_band(from_offset: float, to_offset: float, color_at: Callable) -> void:
	var n := points.size()
	for i in n:
		var j := (i + 1) % n
		var quad := PackedVector2Array(
			[
				points[i] + _normals[i] * from_offset,
				points[j] + _normals[j] * from_offset,
				points[j] + _normals[j] * to_offset,
				points[i] + _normals[i] * to_offset,
			]
		)
		var color: Color = color_at.call(i)
		if color.a > 0.0:
			draw_colored_polygon(quad, color)


func _draw_edges() -> void:
	var half := road_width * 0.5
	var curb_color := func(i: int) -> Color:
		if not _curvy[i]:
			return Color.TRANSPARENT
		return curb_red if i % 4 < 2 else curb_white
	var line := func(i: int) -> Color: return Color.TRANSPARENT if _curvy[i] else line_color
	for side in [-1.0, 1.0]:
		_draw_band(side * half, side * (half + curb_width), curb_color)
		_draw_band(side * (half - 10.0), side * (half - 4.0), line)


func _draw_start_line() -> void:
	var tangent := (points[1] - points[0]).normalized()
	var normal := _normals[0]
	var squares := 12
	var size := road_width / squares
	for row in 2:
		for col in squares:
			var color := Color("f2efe6") if (row + col) % 2 == 0 else Color("1a1a18")
			var origin := (
				points[0] + normal * (-road_width * 0.5 + col * size) + tangent * (row * size)
			)
			draw_colored_polygon(
				PackedVector2Array(
					[
						origin,
						origin + normal * size,
						origin + normal * size + tangent * size,
						origin + tangent * size,
					]
				),
				color
			)


func _draw_tyres(wall: PackedVector2Array) -> void:
	var n := wall.size()
	for i in n:
		var p := wall[i]
		draw_circle(p, 11.0, tyre_color)
		draw_circle(p, 5.0, tyre_color.lightened(0.12))
		if i % 12 == 0:
			draw_arc(p, 9.0, 0.0, TAU, 12, curb_white, 3.0)


func _build_walls() -> void:
	var segments := PackedVector2Array()
	for wall in [_outer_wall, _inner_wall]:
		for i in wall.size():
			segments.append(wall[i])
			segments.append(wall[(i + 1) % wall.size()])
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.add_child(collision)
	add_child(body)


func _offset(distance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points.size():
		result.append(points[i] + _normals[i] * distance)
	return result


static func _catmull_rom(ctrl: PackedVector2Array, steps: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n := ctrl.size()
	for i in n:
		var p0 := ctrl[(i - 1 + n) % n]
		var p1 := ctrl[i]
		var p2 := ctrl[(i + 1) % n]
		var p3 := ctrl[(i + 2) % n]
		for s in steps:
			var t := float(s) / steps
			var t2 := t * t
			var t3 := t2 * t
			result.append(
				(
					0.5
					* (
						2.0 * p1
						+ (p2 - p0) * t
						+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
						+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3
					)
				)
			)
	return result


static func _resample(path: PackedVector2Array, spacing: float) -> PackedVector2Array:
	var result := PackedVector2Array([path[0]])
	var carry := 0.0
	var n := path.size()
	for i in n:
		var a := path[i]
		var b := path[(i + 1) % n]
		var seg := a.distance_to(b)
		var d := spacing - carry
		while d <= seg:
			result.append(a.lerp(b, d / seg))
			d += spacing
		carry = seg - (d - spacing)
	if result[result.size() - 1].distance_to(result[0]) < spacing * 0.5:
		result.remove_at(result.size() - 1)
	return result


static func _compute_normals(path: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	var n := path.size()
	for i in n:
		var tangent := (path[(i + 1) % n] - path[(i - 1 + n) % n]).normalized()
		result.append(tangent.orthogonal())
	return result


static func _compute_curvy(path: PackedVector2Array) -> PackedByteArray:
	var n := path.size()
	var raw := PackedByteArray()
	raw.resize(n)
	for i in n:
		var a := (path[i] - path[(i - 3 + n) % n]).angle()
		var b := (path[(i + 3) % n] - path[i]).angle()
		var turn := absf(angle_difference(a, b))
		var radius := (SAMPLE_SPACING * 3.0) / maxf(turn, 0.0001)
		raw[i] = 1 if radius < CURB_MAX_RADIUS else 0
	# Kurze Lücken schließen, damit Randsteine nicht flackern
	var result := raw.duplicate()
	for i in n:
		if raw[i] == 0:
			for k in range(-4, 5):
				if raw[(i + k + n) % n] == 1:
					result[i] = 1
					break
	return result
