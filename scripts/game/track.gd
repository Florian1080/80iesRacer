class_name Track
extends Node2D
## Rundkurs, der aus wenigen Stützpunkten erzeugt wird.
##
## Aus den Stützpunkten entsteht eine glatte Mittellinie. Daraus werden Asphalt,
## Randsteine und Kiesbetten (nur in Kurven), weiße Randlinien, Start-Ziel-Linie,
## Startaufstellung und die Begrenzungsmauern berechnet. Auf Geraden sind die
## Mauern aus Beton, in Kurven aus Reifenstapeln, an besonders engen Stellen
## liegen Strohballen davor. Die Mittellinie dient später auch den
## Computer-Gegnern als Ideallinie.

enum Surface { ROAD, GRASS, GRAVEL }
enum WallStyle { CONCRETE, TYRES, BALES }

const SAMPLE_SPACING := 24.0
const CURB_MAX_RADIUS := 1100.0

## Gemischte 80er-Rennstrecke: lange Start-Ziel-Gerade, schnelle S-Kurven,
## Schikane, Haarnadel, enge Rechtskurve und weite Schlusskurve.
@export var control_points := PackedVector2Array(
	[
		Vector2(-600, 0),
		Vector2(2400, 0),
		Vector2(3300, -350),
		Vector2(3600, -1150),
		Vector2(3380, -1950),
		Vector2(3600, -2750),
		Vector2(3050, -3600),
		Vector2(1700, -3900),
		Vector2(900, -3900),
		Vector2(350, -3660),
		Vector2(-250, -3660),
		Vector2(-800, -3900),
		Vector2(-2200, -3950),
		Vector2(-3250, -3700),
		Vector2(-3300, -2850),
		Vector2(-2450, -2550),
		Vector2(-1300, -2450),
		Vector2(-700, -1850),
		Vector2(-1250, -1150),
		Vector2(-2500, -1000),
		Vector2(-3350, -750),
		Vector2(-3400, -200),
		Vector2(-2500, 0),
	]
)
## Stützpunkte, an denen Strohballen vor den Reifenstapeln liegen.
@export var bale_corners := PackedInt32Array([9, 10, 13, 14, 17])
@export var road_width := 300.0
@export var runoff := 170.0
@export var curb_width := 16.0

@export_group("Farben")
@export var grass_color := Color("5b7a3c")
@export var grass_stripe_color := Color("648343")
@export var gravel_color := Color("c4ad84")
@export var gravel_dark := Color("a8916a")
@export var asphalt_color := Color("4b4b48")
@export var line_color := Color("e6e0cf")
@export var curb_red := Color("b8372b")
@export var curb_white := Color("ebe5d6")
@export var tyre_color := Color("1e1e1c")
@export var concrete_color := Color("b4afa3")
@export var bale_color := Color("e2b43c")

## Geglättete Mittellinie, gleichmäßig verteilt.
var points := PackedVector2Array()
## Seitenvektor je Punkt. Zeigt aus Fahrersicht nach links.
var normals := PackedVector2Array()

var _curvy := PackedByteArray()
var _outside := PackedInt32Array()
var _left_offset := PackedFloat32Array()
var _right_offset := PackedFloat32Array()
var _left_style := PackedByteArray()
var _right_style := PackedByteArray()


func _ready() -> void:
	points = _resample(_catmull_rom(control_points, 20), SAMPLE_SPACING)
	normals = _compute_normals(points)
	_analyse_corners()
	_build_walls()
	queue_redraw()


func get_surface(pos: Vector2) -> Surface:
	var i := nearest_index(pos)
	var side := (pos - points[i]).dot(normals[i])
	if absf(side) <= road_width * 0.5 + curb_width:
		return Surface.ROAD
	if _curvy[i] and signf(side) == _outside[i]:
		return Surface.GRAVEL
	return Surface.GRASS


## Liegt die Position auf Asphalt (inklusive Randsteinen)?
func is_on_road(pos: Vector2) -> bool:
	return get_surface(pos) == Surface.ROAD


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


## Punkt neben der Strecke: Index entlang der Mittellinie (darf negativ sein),
## seitlicher Abstand (positiv = links in Fahrtrichtung).
func point_beside(index: int, side_offset: float) -> Vector2:
	var i := posmod(index, points.size())
	return points[i] + normals[i] * side_offset


func tangent_at(index: int) -> Vector2:
	var n := points.size()
	return (points[posmod(index + 1, n)] - points[posmod(index - 1, n)]).normalized()


## Abstand der äußeren Mauer von der Mittellinie.
func wall_distance() -> float:
	return road_width * 0.5 + runoff


## Tatsächlicher Mauerabstand an einem Punkt (innen in engen Kurven kleiner).
func wall_offset(index: int, side: float) -> float:
	var i := posmod(index, points.size())
	return _left_offset[i] if side > 0.0 else _right_offset[i]


func is_curvy(index: int) -> bool:
	return _curvy[posmod(index, points.size())] == 1


## Kurvenaußenseite an einem Punkt: 1 = links, -1 = rechts.
func outside_side(index: int) -> int:
	return _outside[posmod(index, points.size())]


## Startposition in der Startaufstellung, versetzt links und rechts.
func get_start_transform(grid_slot := 0) -> Transform2D:
	var index := posmod(-5 - grid_slot * 4, points.size())
	var tangent := tangent_at(index)
	var side := 1.0 if grid_slot % 2 == 0 else -1.0
	var pos := points[index] + normals[index] * side * road_width * 0.22
	return Transform2D(tangent.angle(), pos)


func _draw() -> void:
	_draw_grass()
	_draw_gravel()
	_draw_band(-road_width * 0.5, road_width * 0.5, func(_i: int) -> Color: return asphalt_color)
	_draw_edges()
	_draw_grid(4)
	_draw_start_line()
	_draw_wall(_left_offset, 1.0, _left_style)
	_draw_wall(_right_offset, -1.0, _right_style)


func _draw_grass() -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	bounds = bounds.grow(2200.0)
	draw_rect(bounds, grass_color)
	var stripe := 140.0
	var x := bounds.position.x
	while x < bounds.end.x:
		draw_rect(Rect2(x, bounds.position.y, stripe, bounds.size.y), grass_stripe_color)
		x += stripe * 2.0


func _draw_gravel() -> void:
	var n := points.size()
	var inner := road_width * 0.5 + curb_width
	var rng := RandomNumberGenerator.new()
	rng.seed = 1985
	for i in n:
		if not _curvy[i]:
			continue
		var j := (i + 1) % n
		var s := float(_outside[i])
		var outer := wall_distance() - 10.0
		draw_colored_polygon(
			PackedVector2Array(
				[
					points[i] + normals[i] * s * inner,
					points[j] + normals[j] * s * inner,
					points[j] + normals[j] * s * outer,
					points[i] + normals[i] * s * outer,
				]
			),
			gravel_color
		)
		for k in 3:
			var off := rng.randf_range(inner + 8.0, outer - 8.0)
			draw_circle(points[i] + normals[i] * s * off, rng.randf_range(2.0, 4.0), gravel_dark)


## Zeichnet ein Band entlang der Mittellinie zwischen zwei seitlichen Abständen.
func _draw_band(from_offset: float, to_offset: float, color_at: Callable) -> void:
	var n := points.size()
	for i in n:
		var j := (i + 1) % n
		var color: Color = color_at.call(i)
		if color.a <= 0.0:
			continue
		draw_colored_polygon(
			PackedVector2Array(
				[
					points[i] + normals[i] * from_offset,
					points[j] + normals[j] * from_offset,
					points[j] + normals[j] * to_offset,
					points[i] + normals[i] * to_offset,
				]
			),
			color
		)


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
	var tangent := tangent_at(0)
	var normal := normals[0]
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


## Weiße Markierungen der Startplätze.
func _draw_grid(slots: int) -> void:
	for slot in slots:
		var start := get_start_transform(slot)
		var forward := start.x.normalized()
		var side := start.y.normalized()
		var front := start.origin + forward * 44.0
		draw_line(front - side * 26.0, front + side * 26.0, line_color, 4.0)
		draw_line(front - side * 26.0, front - side * 26.0 - forward * 22.0, line_color, 4.0)
		draw_line(front + side * 26.0, front + side * 26.0 - forward * 22.0, line_color, 4.0)


func _draw_wall(offsets: PackedFloat32Array, side: float, styles: PackedByteArray) -> void:
	var n := points.size()
	for i in n:
		var j := (i + 1) % n
		var a := points[i] + normals[i] * side * offsets[i]
		match styles[i]:
			WallStyle.CONCRETE:
				var b := points[j] + normals[j] * side * offsets[j]
				draw_line(a, b, concrete_color, 14.0)
				draw_line(
					a - normals[i] * side * 6.0,
					b - normals[j] * side * 6.0,
					concrete_color.lightened(0.15),
					3.0
				)
			WallStyle.TYRES:
				draw_circle(a, 11.0, tyre_color)
				draw_circle(a, 5.0, tyre_color.lightened(0.12))
				if i % 12 == 0:
					draw_arc(a, 9.0, 0.0, TAU, 12, curb_white, 3.0)
			WallStyle.BALES:
				draw_circle(a, 11.0, tyre_color)
				if i % 2 == 0:
					var t := tangent_at(i)
					var c := a - normals[i] * side * 22.0
					var bale := PackedVector2Array(
						[
							c - t * 22.0 - normals[i] * 12.0,
							c + t * 22.0 - normals[i] * 12.0,
							c + t * 22.0 + normals[i] * 12.0,
							c - t * 22.0 + normals[i] * 12.0,
						]
					)
					draw_colored_polygon(bale, bale_color)
					draw_polyline(
						bale + PackedVector2Array([bale[0]]), bale_color.darkened(0.3), 2.0
					)


func _analyse_corners() -> void:
	var n := points.size()
	var turn := PackedFloat32Array()
	var radius := PackedFloat32Array()
	turn.resize(n)
	radius.resize(n)
	for i in n:
		var a := (points[i] - points[(i - 3 + n) % n]).angle()
		var b := (points[(i + 3) % n] - points[i]).angle()
		turn[i] = angle_difference(a, b)
		radius[i] = (SAMPLE_SPACING * 3.0) / maxf(absf(turn[i]), 0.0001)

	_curvy.resize(n)
	_outside.resize(n)
	var raw_curvy := PackedByteArray()
	raw_curvy.resize(n)
	var smooth_radius := PackedFloat32Array()
	smooth_radius.resize(n)
	for i in n:
		var turn_sum := 0.0
		var min_r := INF
		for k in range(-8, 9):
			var idx := (i + k + n) % n
			turn_sum += turn[idx]
			min_r = minf(min_r, radius[idx])
		# Rechtskurve: außen ist links (positive Seite)
		_outside[i] = 1 if turn_sum > 0.0 else -1
		smooth_radius[i] = min_r
		raw_curvy[i] = 1 if radius[i] < CURB_MAX_RADIUS else 0
	for i in n:
		_curvy[i] = raw_curvy[i]
		if raw_curvy[i] == 0:
			for k in range(-4, 5):
				if raw_curvy[(i + k + n) % n] == 1:
					_curvy[i] = 1
					break

	# Innere Mauer rückt in engen Kurven näher, damit sie sich nicht überschneidet
	var min_offset := road_width * 0.5 + curb_width + 40.0
	var left_raw := PackedFloat32Array()
	var right_raw := PackedFloat32Array()
	left_raw.resize(n)
	right_raw.resize(n)
	for i in n:
		var tight := maxf(min_offset, smooth_radius[i] * 0.8)
		var inside_offset := minf(wall_distance(), tight)
		left_raw[i] = inside_offset if _outside[i] == -1 else wall_distance()
		right_raw[i] = inside_offset if _outside[i] == 1 else wall_distance()
	_left_offset = _smooth(left_raw, 8)
	_right_offset = _smooth(right_raw, 8)

	# Mauertypen: Beton auf Geraden, Reifen in Kurven, Strohballen an engen Stellen
	var bale_index := PackedInt32Array()
	for c in bale_corners:
		if c >= 0 and c < control_points.size():
			bale_index.append(nearest_index(control_points[c]))
	_left_style.resize(n)
	_right_style.resize(n)
	for i in n:
		var style := WallStyle.CONCRETE
		for k in range(-10, 11):
			if _curvy[(i + k + n) % n]:
				style = WallStyle.TYRES
				break
		for b in bale_index:
			var gap := absi(i - b)
			if mini(gap, n - gap) < 22:
				style = WallStyle.BALES
		_left_style[i] = style
		_right_style[i] = style


func _build_walls() -> void:
	var segments := PackedVector2Array()
	var n := points.size()
	for side_data in [[_left_offset, 1.0], [_right_offset, -1.0]]:
		var offsets: PackedFloat32Array = side_data[0]
		var side: float = side_data[1]
		for i in n:
			var j := (i + 1) % n
			segments.append(points[i] + normals[i] * side * offsets[i])
			segments.append(points[j] + normals[j] * side * offsets[j])
	var shape := ConcavePolygonShape2D.new()
	shape.segments = segments
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.add_child(collision)
	add_child(body)


static func _smooth(values: PackedFloat32Array, window: int) -> PackedFloat32Array:
	var n := values.size()
	var result := PackedFloat32Array()
	result.resize(n)
	for i in n:
		var total := 0.0
		for k in range(-window, window + 1):
			total += values[(i + k + n) % n]
		result[i] = total / (window * 2 + 1)
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
