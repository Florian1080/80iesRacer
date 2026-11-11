class_name TrackDecor
extends Node2D
## Alles neben der Fahrbahn: Tribünen, Werbebanden, Startturm mit Ampel,
## Boxengasse mit Garagen und Streckenposten.
## Positionen werden relativ zur Strecke angegeben (Index entlang der Mittellinie),
## damit die Deko automatisch mitwandert, wenn sich das Layout ändert.

## Erfundene Marken im 80er-Stil: [Text, Hintergrund, Schrift].
const BRANDS := [
	["TURBO COLA", Color("b8372b"), Color("f2ead8")],
	["KASSETTEN KING", Color("2f4a3a"), Color("e0b52a")],
	["VIDEOTHEK 2000", Color("e0b52a"), Color("2b2a26")],
	["WALKMAN WELT", Color("27405e"), Color("f2ead8")],
	["SUPER BENZIN", Color("f2ead8"), Color("b8372b")],
	["DISKETTEN DIREKT", Color("6b3d2a"), Color("f2ead8")],
	["RALLYE REIFEN", Color("2b2a26"), Color("e0b52a")],
	["HAARSPRAY EXTRA", Color("c47a35"), Color("2b2a26")],
]
const TEAM_COLORS := [
	Color("b8372b"), Color("27405e"), Color("2f4a3a"), Color("e0b52a"), Color("6b3d2a")
]

@export var track_path: NodePath = ^"../Track"
## Ampel am Startturm: Anzahl leuchtender roter Lampen (0 bis 5).
@export_range(0, 5) var start_lights := 0:
	set(value):
		start_lights = value
		queue_redraw()
@export var lights_green := false:
	set(value):
		lights_green = value
		queue_redraw()

var _track: Track
var _font: Font


func _ready() -> void:
	_track = get_node(track_path)
	_font = ThemeDB.fallback_font
	_place_marshals()
	queue_redraw()


func _draw() -> void:
	if _track == null:
		return
	var wall := _track.wall_distance()
	_draw_pits(wall)
	_draw_grandstand(-62, -8, -1.0, wall + 70.0)
	_draw_grandstand(8, 110, -1.0, wall + 70.0)
	_draw_boards()
	_draw_start_tower(wall)


## Tribünen außen an der Start-Ziel-Geraden, mit Zuschauern.
func _draw_grandstand(from_index: int, to_index: int, side: float, offset: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1986
	var depth := 230.0
	var rows := 7
	var crowd := [
		Color("b8372b"),
		Color("27405e"),
		Color("e0b52a"),
		Color("f2ead8"),
		Color("2f4a3a"),
		Color("c47a35"),
		Color("7a6a8a"),
		Color("d8d2c4"),
	]
	var block := 16
	var i := from_index
	while i < to_index:
		var end := mini(i + block, to_index)
		var a0 := _track.point_beside(i, side * offset)
		var a1 := _track.point_beside(end, side * offset)
		var b0 := _track.point_beside(i, side * (offset + depth))
		var b1 := _track.point_beside(end, side * (offset + depth))
		draw_colored_polygon(PackedVector2Array([a0, a1, b1, b0]), Color("8f8a7e"))
		for r in rows:
			var t0 := float(r) / rows
			var t1 := float(r + 1) / rows
			var s0 := a0.lerp(b0, t0)
			var s1 := a1.lerp(b1, t0)
			var e0 := a0.lerp(b0, t1)
			var e1 := a1.lerp(b1, t1)
			var step_color := Color("a39d90") if r % 2 == 0 else Color("989285")
			draw_colored_polygon(PackedVector2Array([s0, s1, e1, e0]), step_color)
			var seats := 22
			for k in seats:
				if rng.randf() < 0.18:
					continue
				var u := (k + 0.5) / seats
				var pos := s0.lerp(s1, u).lerp(e0.lerp(e1, u), 0.5)
				draw_circle(pos, 6.0, crowd[rng.randi() % crowd.size()])
				draw_circle(pos, 3.0, Color("e8c49a"))
		# Dach hinten
		var r0 := _track.point_beside(i, side * (offset + depth + 40.0))
		var r1 := _track.point_beside(end, side * (offset + depth + 40.0))
		draw_colored_polygon(PackedVector2Array([b0, b1, r1, r0]), Color("6e695f"))
		draw_line(b0, b1, Color("4f4b44"), 4.0)
		i = end + 2


## Startturm neben der Start-Ziel-Linie, mit fünf Ampellampen zur Strecke hin.
func _draw_start_tower(wall: float) -> void:
	var side := -1.0
	var base := _track.point_beside(0, side * (wall + 30.0))
	var t := _track.tangent_at(0)
	var n := _track.normals[0] * side
	var size_t := 110.0
	var size_n := 90.0
	var corners := PackedVector2Array(
		[
			base - t * size_t * 0.5,
			base + t * size_t * 0.5,
			base + t * size_t * 0.5 + n * size_n,
			base - t * size_t * 0.5 + n * size_n,
		]
	)
	draw_colored_polygon(corners, Color("d8d2c4"))
	draw_polyline(corners + PackedVector2Array([corners[0]]), Color("6e695f"), 3.0)
	# Schriftzug-Band
	draw_colored_polygon(
		PackedVector2Array([corners[2], corners[3], corners[3] - n * 22.0, corners[2] - n * 22.0]),
		Color("b8372b")
	)
	# Lampenleiste an der Streckenseite
	var panel := base + n * 8.0
	draw_colored_polygon(
		PackedVector2Array(
			[
				panel - t * 50.0 - n * 18.0,
				panel + t * 50.0 - n * 18.0,
				panel + t * 50.0 + n * 10.0,
				panel - t * 50.0 + n * 10.0,
			]
		),
		Color("1d1d1b")
	)
	for k in 5:
		var pos := panel + t * (-40.0 + k * 20.0) - n * 4.0
		var color := Color("3a1512")
		if lights_green:
			color = Color("4fbf5a")
		elif k < start_lights:
			color = Color("e8392b")
		draw_circle(pos, 8.0, color)


## Boxengasse innen an der Start-Ziel-Geraden: Fahrspur, Boxenmauer, Garagen.
func _draw_pits(wall: float) -> void:
	var side := 1.0
	var from_index := -30
	var to_index := 75
	var lane_from := wall + 24.0
	var lane_to := wall + 130.0
	for i in range(from_index, to_index):
		var quad := PackedVector2Array(
			[
				_track.point_beside(i, side * lane_from),
				_track.point_beside(i + 1, side * lane_from),
				_track.point_beside(i + 1, side * lane_to),
				_track.point_beside(i, side * lane_to),
			]
		)
		draw_colored_polygon(quad, Color("55554f"))
		if i % 3 == 0:
			draw_line(
				_track.point_beside(i, side * (lane_from + 52.0)),
				_track.point_beside(i + 1, side * (lane_from + 52.0)),
				Color("d8d2c4"),
				3.0
			)
	# Garagen
	var garage := 7
	var number := 1
	var i := from_index + 2
	while i + garage <= to_index:
		var g0 := _track.point_beside(i, side * (lane_to + 4.0))
		var g1 := _track.point_beside(i + garage - 1, side * (lane_to + 4.0))
		var h0 := _track.point_beside(i, side * (lane_to + 150.0))
		var h1 := _track.point_beside(i + garage - 1, side * (lane_to + 150.0))
		var team: Color = TEAM_COLORS[number % TEAM_COLORS.size()]
		draw_colored_polygon(PackedVector2Array([g0, g1, h1, h0]), Color("cfc9bb"))
		draw_colored_polygon(
			PackedVector2Array([g0, g1, g1.lerp(h1, 0.18), g0.lerp(h0, 0.18)]), team
		)
		draw_polyline(PackedVector2Array([g0, g1, h1, h0, g0]), Color("6e695f"), 2.0)
		var mid := g0.lerp(g1, 0.5).lerp(h0.lerp(h1, 0.5), 0.6)
		_draw_text_at(str(number), mid, _track.tangent_at(i), 34, Color("6e695f"))
		number += 1
		i += garage


## Werbebanden hinter den Betonmauern auf den Geraden.
func _draw_boards() -> void:
	var n := _track.points.size()
	var brand := 0
	var spacing := 22
	var length := 11
	var i := 0
	while i < n:
		var straight := true
		for k in range(-12, length + 12):
			if _track.is_curvy(i + k):
				straight = false
				break
		if straight:
			for side in [-1.0, 1.0]:
				if side > 0.0 and (i < 80 or i > n - 35):
					continue
				if side < 0.0 and (i < 8 or i > n - 18):
					continue
				_draw_board(i, length, side, BRANDS[brand % BRANDS.size()])
				brand += 1
		i += spacing


func _draw_board(index: int, length: int, side: float, data: Array) -> void:
	var offset := _track.wall_offset(index, side) + 16.0
	var a0 := _track.point_beside(index, side * offset)
	var a1 := _track.point_beside(index + length, side * offset)
	var b0 := _track.point_beside(index, side * (offset + 30.0))
	var b1 := _track.point_beside(index + length, side * (offset + 30.0))
	var bg: Color = data[1]
	var fg: Color = data[2]
	draw_colored_polygon(PackedVector2Array([a0, a1, b1, b0]), bg)
	draw_polyline(PackedVector2Array([a0, a1, b1, b0, a0]), bg.darkened(0.35), 2.0)
	var center := a0.lerp(a1, 0.5).lerp(b0.lerp(b1, 0.5), 0.5)
	_draw_text_at(data[0], center, a1 - a0, 20, fg)


## Zeichnet Text mittig an einer Position, ausgerichtet entlang einer Richtung.
## Text wird so gedreht, dass er von oben gesehen nie auf dem Kopf steht.
func _draw_text_at(
	text: String, center: Vector2, direction: Vector2, size: int, color: Color
) -> void:
	var angle := direction.angle()
	if absf(angle) > PI * 0.5:
		angle += PI
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_set_transform(center, angle)
	draw_string(
		_font, Vector2(-width * 0.5, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color
	)
	draw_set_transform(Vector2.ZERO)


## Streckenposten außen an den wichtigsten Kurven.
func _place_marshals() -> void:
	var corners := {
		2: Color("e0b52a"),
		6: Color("4fa55a"),
		9: Color("e0b52a"),
		13: Color("e0b52a"),
		17: Color("e0b52a"),
		20: Color("4fa55a")
	}
	for c: int in corners:
		if c >= _track.control_points.size():
			continue
		var i := _track.nearest_index(_track.control_points[c])
		var side := float(_track.outside_side(i))
		var marshal := Marshal.new()
		marshal.flag_color = corners[c]
		marshal.position = _track.point_beside(i, side * (_track.wall_distance() + 55.0))
		marshal.rotation = (_track.normals[i] * -side).angle()
		add_child(marshal)
