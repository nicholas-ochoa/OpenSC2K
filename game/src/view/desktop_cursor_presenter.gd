class_name DesktopCursorPresenter
extends Node
# this cursor is an operation on the screen, not just an image
# native pointers for ordinary art; a small gpu patch for original xor art

const XOR_SHADER := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	ivec3 background = ivec3(round(textureLod(screen_image, SCREEN_UV, 0.0).rgb * 255.0));
	ivec3 foreground = ivec3(round(mask.rgb * 255.0));
	ivec3 result = (mask.a > 0.5 ? background : ivec3(0)) ^ foreground;
	COLOR = vec4(vec3(result) / 255.0, 1.0);
}
"""

var graphics: DesktopGraphics
var active_app := ""
var active_group := -1
var active_shape := -1
var active_record: DesktopGraphics.Cursor
var upload_count := 0
var _textures: Dictionary[String, ImageTexture] = {}
var _layer: CanvasLayer
var _copy: BackBufferCopy
var _patch: TextureRect
var _owns_hidden_mouse := false


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_copy = BackBufferCopy.new()
	_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
	_layer.add_child(_copy)
	_patch = TextureRect.new()
	_patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := Shader.new()
	shader.code = XOR_SHADER
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	_patch.material = shader_material
	_layer.add_child(_patch)
	_layer.hide()
	_copy.hide()


func set_graphics(value: DesktopGraphics) -> void:
	if graphics == value:
		return

	clear_cursor()
	graphics = value
	_textures.clear()

	if _patch != null:
		_patch.texture = null


func present(app: String, group: int, point: Vector2, shape: int) -> void:
	var record := graphics.cursor(app, group) if graphics != null else null

	if record == null:
		clear_cursor()

		return

	if active_app != app or active_group != group or active_shape != shape:
		clear_cursor()
		active_app = app
		active_group = group
		active_shape = shape
		active_record = record
		var key := "%s:%d" % [app, group]

		if not _textures.has(key):
			var image: Image = record.image

			if image == null:
				image = mask_image(record.masked)

			_textures[key] = ImageTexture.create_from_image(image)
			upload_count += 1

		if record.image != null:
			Input.set_custom_mouse_cursor(_textures[key], shape, Vector2(record.hotspot))
		else:
			_patch.texture = _textures[key]
			_patch.size = Vector2(32, 32)
			_layer.show()
			_copy.show()

			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
				_owns_hidden_mouse = true

	if record.image == null:
		_patch.position = point.floor() - Vector2(record.hotspot)
		_copy.rect = Rect2(_patch.position, _patch.size)


func clear_cursor() -> void:
	if active_shape >= 0 and active_record != null and active_record.image != null:
		Input.set_custom_mouse_cursor(null, active_shape)

	if _owns_hidden_mouse:
		if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

		_owns_hidden_mouse = false

	active_app = ""
	active_group = -1
	active_shape = -1
	active_record = null

	if _layer != null:
		_layer.hide()
		_copy.hide()


static func mask_image(masked: PeIconCursorResource.DecodedImage) -> Image:
	var image := Image.create(masked.width, masked.height, false, Image.FORMAT_RGBA8)

	for y in masked.height:
		for x in masked.width:
			var at: int = y * masked.width + x
			var color: Color = masked.palette[masked.pixels[at]]
			color.a = float(masked.and_mask[at])
			image.set_pixel(x, y, color)

	return image


func _exit_tree() -> void:
	clear_cursor()
