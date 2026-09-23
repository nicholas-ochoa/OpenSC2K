class_name ScurkProjectLimits
extends RefCounted

const MAX_FILE_BYTES := 128 * 1024 * 1024
const MAX_DATA_BYTES := 64 * 1024 * 1024
const MAX_MIF_BYTES := 16 * 1024 * 1024
const MAX_DOCUMENTS := 1500
const MAX_LAYERS := 32
const MAX_STAMPS := 256
const MAX_CHECKPOINTS := 24
const MAX_RESOURCES := 1024
const MAX_WIDTH := 128
const MAX_HEIGHT := 256


static func integer_in(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= minimum and value <= maximum


static func valid_dimensions(width: Variant, height: Variant) -> bool:
	return integer_in(width, 1, MAX_WIDTH) and integer_in(height, 1, MAX_HEIGHT)
