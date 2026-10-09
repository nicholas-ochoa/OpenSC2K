class_name JohabCodec
extends RefCounted
## Original Korean text uses Johab, whose trail bytes include ASCII characters.
## Newspaper grammar also has opcodes; plain TXT resources do not. The native
## formats library holds the codec; see native/core/assets/src/text/johab.rs.


# The Unicode code point of the Johab pair at `at`, or 0 for an invalid pair.
static func code_point(bytes: PackedByteArray, at: int) -> int:
	return NativeJohab.code_point(bytes, at)


# Detect the whole text resource file, not only the requested short label.
# Every high byte must form a valid pair.
static func is_text(bytes: PackedByteArray, record_boundaries := PackedInt32Array()) -> bool:
	return NativeJohab.is_text(bytes, record_boundaries)


# The caller has already identified the file. An invalid pair keeps the Latin-1 text.
static func decode_text(bytes: PackedByteArray) -> String:
	return NativeJohab.decode_text(bytes)


# Whether newspaper grammar is Johab text. Opcode arguments can be pair trails.
static func is_grammar(grammar: PackedByteArray, offsets: PackedByteArray) -> bool:
	return NativeJohab.is_grammar(grammar, offsets)
