class_name FixtureGraphics
extends RefCounted
## Imported graphics for renderer tests. Decoder audits use the supplied archives.

static var _pack: GraphicsPack


static func pack() -> GraphicsPack:
	if _pack == null:
		_pack = GraphicsPack.load_root("res://../ext/graphics")
		assert(_pack.error.is_empty(), _pack.error)

	return _pack
