class_name CityGpuRegionResult
extends CityRegionResult

var gpu_arrays: Array = []
var tile_builds := 0
var tile_reuses := 0
var gpu_draws: Array[CityGpuDrawList.Draw] = []
var background := Color.TRANSPARENT
var atlas_revision := -1
var atlas_edge := 0
var atlas_image: Image
var sign_foregrounds: Dictionary[int, CitySignForegroundPatch] = {}
var mesh: ArrayMesh
var atlas_texture: ImageTexture
# Meshes and bounds stay fixed after publication. Views share this descriptor.
var source_entry: CityMapSource.MeshEntry


var _draw_grid: Dictionary[Vector2i, Array] = {}
var _draw_grid_ready := false


# Index the draws for CPU pixel reads on first use. Most regions never need it.
func draw_grid() -> Dictionary[Vector2i, Array]:
	if not _draw_grid_ready:
		_draw_grid = CityGpuDrawList.build_grid(gpu_draws)
		_draw_grid_ready = true

	return _draw_grid


static func failed(message: String) -> CityGpuRegionResult:
	var result := CityGpuRegionResult.new()
	result.error = message

	return result
