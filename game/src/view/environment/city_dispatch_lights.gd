class_name CityDispatchLights
extends RefCounted
## Retain the original raised dispatch symbols at night; their posts stay unlit.
## Bounds apply only to matching standard artwork, independently at each zoom.

const HEADS := {
	1382: [32, 70, 29, "89fb55efcfc3aada432600d508ba5c624213955fcc167837e979b05ebfd03f40"],
	1383: [32, 78, 38, "6c5ed85bc59d994a844511608a7dd48061add45352197643345a807b6aab15e4"],
	1384: [32, 69, 28, "51bbd3a6518e9e98bf577c4b06d93127ca73d7eaaa8158198f465d170f6d5366"],
	882: [16, 38, 15, "f44e7993809ac50d5e3963fae992658bbb3687276c3d30b3259683008f3ba600"],
	883: [16, 40, 20, "4c131e0b1740f79e9d24f810a2aa3e50632422c85aa10612c189a2988ef013a1"],
	884: [16, 38, 15, "318cbf5bd1315e391ee18cbd5911ec1d9347fb7b887df859d685ffbe73261eb0"],
	382: [8, 22, 10, "51d52e49f7a38f14f99af788ddd6278f5d9dfb13f509ad2bb209adcca394e0c2"],
	383: [8, 24, 12, "dd0695fad974c9be51e54b745be15dc2ab96b0bf7d8ce2bb975d13b6449c2472"],
	384: [8, 19, 8, "2e502280760df6638be8b80c35442d2a671bb5f43193ef210e674f9c3d50dc09"],
}


static func prepare(archive: Sc2SpriteArchive, palette: Sc2Palette) -> void:
	for id: int in HEADS:
		if archive.visual_emission.has(id):
			continue
		var entry := archive.find_sprite(id)
		var head: Array = HEADS[id]
		if entry == null or entry.width != head[0] or entry.height != head[1] \
				or CityBrightmaps.fingerprint(entry) != head[3]:
			continue
		var original := entry.create_image(palette)
		if not original.ok:
			continue
		var mask := Image.create(entry.width, entry.height, false, Image.FORMAT_RGBA8)
		mask.blit_rect(original.image, Rect2i(0, 0, entry.width, head[2]), Vector2i.ZERO)
		archive.visual_emission[id] = mask
