class_name CityMapSource
extends RefCounted
# base-layer content for citymapcontrol. positions and sizes are in source pixels
#
# one of three shapes:
# - whole: `texture` holds the complete map and draws on the base layer
# - tiled: `texture` is null; `tiles` and `meshes` draw as base-layer children
#   citymaptexture splits images above its size limit; cityregioncache publishes
#   the visible regions
# - extent only: `texture` is null and there are no entries (data views)


class TileEntry:
	extends RefCounted

	var position: Vector2
	var size: Vector2
	var texture: Texture2D


	func _init(source_position: Vector2, source_size: Vector2, tile_texture: Texture2D) -> void:
		position = source_position
		size = source_size
		texture = tile_texture


class MeshEntry:
	extends RefCounted

	# Region results opt in after upload. Their descriptors never change.
	var immutable := false
	var position: Vector2
	var mesh: Mesh
	var texture: Texture2D
	var divisor: int


	func _init(source_position: Vector2, region_mesh: Mesh, atlas_texture: Texture2D, mesh_divisor: int) -> void:
		position = source_position
		mesh = region_mesh
		texture = atlas_texture
		divisor = mesh_divisor


var size: Vector2i
# the whole-map texture, or null when the map draws from entries or not at all
var texture: Texture2D
var tiles: Array[TileEntry] = []
var meshes: Array[MeshEntry] = []
# Region snapshots can replace a few entries without changing their order.
# Keep only the predecessor ID, never a reference that retains older meshes.
var mesh_updates_from := 0
var mesh_updates := PackedInt32Array()


func _init(source_size: Vector2i, whole_texture: Texture2D = null) -> void:
	size = source_size
	texture = whole_texture


static func whole(whole_texture: Texture2D) -> CityMapSource:
	return CityMapSource.new(Vector2i(whole_texture.get_size()), whole_texture)
