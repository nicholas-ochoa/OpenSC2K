extends "res://tests/support/core_test_suite.gd"

## Scurk: indexed bitmap checks.

@warning_ignore_start("integer_division")

const Palette = preload("res://src/assets/sc2_palette.gd")
const IndexedBitmap = preload("res://src/assets/indexed_bmp.gd")
const ClipboardImage = preload("res://src/platform/image_clipboard.gd")


func test_indexed_bmp() -> void:
	var index_palette := Palette.index_encoding()
	var source_pixels := PackedInt32Array([
		-1, 1, 2,
		3, 4, 5,
	])
	var encoded := IndexedBitmap.encode(3, 2, source_pixels, index_palette)
	_check(encoded.ok, "SCURK indexed BMP encoder accepts valid pixels")

	if not encoded.ok:
		return

	var bytes: PackedByteArray = encoded.bytes
	_check(
		bytes.size() == 1086
		and bytes[0] == 0x42
		and bytes[1] == 0x4d
		and bytes[10] == 0x36
		and bytes[11] == 0x04
		and bytes[1078] == 3
		and bytes[1079] == 4
		and bytes[1080] == 5
		and bytes[1081] == 0
		and bytes[1082] == 0
		and bytes[1083] == 1
		and bytes[1084] == 2
		and bytes[1085] == 0,
		"SCURK BMP output has a 256-color header and padded bottom-up rows",
	)
	var decoded := IndexedBitmap.decode(bytes)
	_check(
		decoded.ok
		and decoded.width == 3
		and decoded.height == 2
		and not decoded.top_down
		and decoded.pixels == PackedInt32Array([0, 1, 2, 3, 4, 5]),
		"SCURK BMP decoder restores indexed rows in display order",
	)
	var mapped := IndexedBitmap.map_to_palette(decoded, index_palette)
	_check(
		mapped.ok
		and mapped.remapped_color_count == 0
		and mapped.pixels == source_pixels,
		"SCURK BMP import maps palette index zero to transparent pixels",
	)
	var compressed := bytes.duplicate()
	compressed[30] = 1
	_check(
		not IndexedBitmap.decode(compressed).ok,
		"SCURK BMP import rejects compressed indexed data",
	)
	var short_palette := bytes.duplicate()
	short_palette[46] = 16
	short_palette[47] = 0
	_check(
		not IndexedBitmap.decode(short_palette).ok,
		"SCURK BMP import rejects a palette with fewer than 256 colors",
	)
	var encoded_dib := IndexedBitmap.encode_dib(
		3, 2, source_pixels, index_palette
	)
	_check(
		encoded_dib.ok
		and encoded_dib.bytes.size() == bytes.size() - 14
		and encoded_dib.bytes[0] == 40
		and encoded_dib.bytes[14] == 8,
		"SCURK clipboard encoder produces a headerless 8-bit CF_DIB payload",
	)
	var decoded_dib := IndexedBitmap.decode_dib(encoded_dib.bytes)
	_check(
		decoded_dib.ok
		and decoded_dib.width == 3
		and decoded_dib.height == 2
		and decoded_dib.pixels == PackedInt32Array([0, 1, 2, 3, 4, 5]),
		"SCURK clipboard decoder restores native CF_DIB indexed rows",
	)
	var wrapped_dib := IndexedBitmap.dib_to_bmp(encoded_dib.bytes)
	_check(
		wrapped_dib.ok and wrapped_dib.bytes == bytes,
		"SCURK CF_DIB wrapper restores the exact indexed BMP bytes",
	)
	var true_color_dib: PackedByteArray = encoded_dib.bytes.duplicate()
	true_color_dib[14] = 24
	_check(
		not IndexedBitmap.decode_dib(true_color_dib).ok,
		"SCURK native clipboard rejects a non-indexed DIB",
	)
	var windows_copy_command := ClipboardImage._copy_command(
		"Windows", "C:\\Temp\\scurk's tile.dib"
	)
	var windows_copy_script: String = windows_copy_command.arguments[4]
	_check(
		windows_copy_command.ok
		and windows_copy_command.arguments.has("-STA")
		and windows_copy_script.contains("DataFormats]::Dib")
		and windows_copy_script.contains("scurk''s tile.dib")
		and not windows_copy_script.contains("SetImage"),
		"SCURK Windows copy publishes the indexed CF_DIB payload on an STA thread",
	)
	var windows_paste_command := ClipboardImage._paste_command(
		"Windows", "C:\\Temp\\scurk-paste.dib"
	)
	var windows_paste_script: String = windows_paste_command.arguments[4]
	_check(
		windows_paste_command.ok
		and windows_paste_script.contains("DataFormats]::Dib")
		and windows_paste_script.contains("WriteAllBytes"),
		"SCURK Windows paste retrieves native indexed CF_DIB bytes",
	)
	var linux_copy_command := ClipboardImage._copy_command(
		"Linux", "/tmp/scurk-copy.bmp", "/usr/bin/xclip"
	)
	_check(
		linux_copy_command.ok
		and linux_copy_command.arguments.has("image/bmp")
		and not linux_copy_command.arguments.has("image/png"),
		"SCURK Linux copy offers the indexed BMP clipboard target",
	)
	var linux_paste_command := ClipboardImage._paste_command(
		"Linux", "/tmp/scurk paste.bmp", "/usr/bin/xclip"
	)
	_check(
		linux_paste_command.ok
		and linux_paste_command.executable == "/bin/sh"
		and String(linux_paste_command.arguments[1]).contains("image/bmp")
		and String(linux_paste_command.arguments[1]).contains("'/tmp/scurk paste.bmp'"),
		"SCURK Linux paste retrieves the indexed BMP clipboard target safely",
	)
	var clipboard_pixels := PackedInt32Array([-1, 0, 1, 255])
	var clipboard_image := ClipboardImage.indexed_to_image(
		2, 2, clipboard_pixels, index_palette
	)
	_check(
		clipboard_image.ok
		and clipboard_image.image.get_pixel(0, 0).a == 0.0
		and clipboard_image.image.get_pixel(1, 0).a == 1.0,
		"SCURK system clipboard image keeps transparent and visible black pixels distinct",
	)
	var clipboard_round_trip := ClipboardImage.image_to_indexed(
		clipboard_image.image, index_palette
	)
	_check(
		clipboard_round_trip.ok
		and clipboard_round_trip.pixels == clipboard_pixels
		and clipboard_round_trip.remapped_color_count == 0,
		"SCURK system clipboard image preserves master-palette pixels",
	)
	var off_palette_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	off_palette_image.set_pixel(0, 0, Color8(17, 18, 19, 255))
	var mapped_clipboard := ClipboardImage.image_to_indexed(
		off_palette_image, index_palette
	)
	_check(
		mapped_clipboard.ok and mapped_clipboard.remapped_color_count == 1,
		"SCURK system clipboard image maps colors outside the master palette",
	)
