extends RefCounted

const CELL_SIZE := 20.0
const VISION_RADIUS := 320.0
const BUNKER_LIGHT_MARGIN := 76.0

var texture: ImageTexture
var _size := Vector2i.ZERO
var _cells := PackedByteArray()
var _texture_dirty := false
var _encoded_state := ""


func reset(bounds: Vector2, bunkers: Array) -> void:
	_size = Vector2i((bounds / CELL_SIZE).ceil())
	_cells = PackedByteArray()
	_cells.resize(_size.x * _size.y)
	for bunker in bunkers:
		var center := Vector2(float(bunker["x"]), float(bunker["y"]))
		var bounds_info := GameRules.get_bunker_bounds(bunker)
		var half_size := Vector2(float(bounds_info["half_w"]), float(bounds_info["half_h"]))
		var lit_area := Rect2(center - half_size, half_size * 2.0).grow(BUNKER_LIGHT_MARGIN)
		var cells := _cell_rect(lit_area)
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				_cells[y * _size.x + x] = 255
	_texture_dirty = false
	_encoded_state = ""
	texture = ImageTexture.create_from_image(_mask_image())


func reveal(center: Vector2, barrier_x: float) -> void:
	var range_px := Vector2.ONE * VISION_RADIUS
	var cells := _cell_rect(Rect2(center - range_px, range_px * 2.0))
	var x_limit := cells.end.x
	if barrier_x > 0.0:
		x_limit = mini(x_limit, floori(barrier_x / CELL_SIZE))
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, x_limit):
			var index := y * _size.x + x
			if _cells[index] == 0 and center.distance_squared_to((Vector2(x, y) + Vector2(0.5, 0.5)) * CELL_SIZE) <= VISION_RADIUS * VISION_RADIUS:
				_cells[index] = 255
				_texture_dirty = true
				_encoded_state = ""


func can_see(position: Vector2) -> bool:
	var cell := Vector2i((position / CELL_SIZE).floor())
	return Rect2i(Vector2i.ZERO, _size).has_point(cell) and _cells[cell.y * _size.x + cell.x] != 0


func refresh_texture() -> void:
	if _texture_dirty:
		texture.update(_mask_image())
		_texture_dirty = false


func encode() -> String:
	if _encoded_state.is_empty() and not _cells.is_empty():
		_encoded_state = Marshalls.raw_to_base64(_cells.compress(FileAccess.COMPRESSION_DEFLATE))
	return _encoded_state


func apply(encoded: String) -> void:
	if encoded.is_empty() or encoded == _encoded_state or _cells.is_empty():
		return
	var cells := Marshalls.base64_to_raw(encoded).decompress(_cells.size(), FileAccess.COMPRESSION_DEFLATE)
	if cells.size() != _cells.size():
		return
	_cells = cells
	_encoded_state = encoded
	_texture_dirty = true


func _cell_rect(area: Rect2) -> Rect2i:
	var top_left := Vector2i((area.position / CELL_SIZE).floor())
	var bottom_right := Vector2i((area.end / CELL_SIZE).ceil())
	return Rect2i(top_left, bottom_right - top_left).intersection(Rect2i(Vector2i.ZERO, _size))


func _mask_image() -> Image:
	return Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_R8, _cells)
