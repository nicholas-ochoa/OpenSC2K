class_name LocalizedNewspaperText
extends RefCounted
## Localized newspaper prose. The imported grammar still determines every saved
## substitution; translated grammar is used only to draw the text.

const Original = preload("res://src/simulation/reports/newspaper_text.gd")
static var PUBLISHED_SEED_OFFSETS: PackedInt64Array = Original.PUBLISHED_SEED_OFFSETS
const TOKENS := {"argument": 36, "section": 43, "paragraph": 45, "city": 61, "team": 62, "mayor": 126}
const ARGUMENT_TOKENS := {"random_number": 37, "argument_table": 38, "random_table": 42,
	"saved_number": 60, "saved_table_second": 64, "shared_table": 91, "saved_table_first": 94}
const GERMAN_OEM := {196: 142, 214: 153, 220: 154, 228: 132, 246: 148, 252: 129}
const CITY_MARKER := "918273645001"
const MAYOR_MARKER := "918273645002"
const TEAM_MARKER := "918273645003"
static var _german: DataUsaResource
static var _literal_markers: Dictionary[String, String] = {}


static func published_seed(session_seed: int, city_days: int, paper_index: int, story_slot: int) -> int:
	return Original.published_seed(session_seed, city_days, paper_index, story_slot)


static func has_data(data: DataUsaResource) -> bool:
	return _translated_data() != null or (data != null and data.is_valid())


static func render_story(data: DataUsaResource, record: NewsQueue.StoryRecord, seed: int,
	city: String, mayor: String, teams: PackedStringArray) -> NewspaperText.Result:
	return _render(data, record, seed, city, mayor, teams, false)


static func render_headline(data: DataUsaResource, record: NewsQueue.StoryRecord, seed: int,
	city: String, mayor: String, teams: PackedStringArray) -> NewspaperText.Result:
	return _render(data, record, seed, city, mayor, teams, true)


static func _render(data: DataUsaResource, record: NewsQueue.StoryRecord, seed: int,
	city: String, mayor: String, teams: PackedStringArray, headline_only: bool) -> NewspaperText.Result:
	var original := (Original.render_headline(data, record, seed, city, mayor, teams) if headline_only
		else Original.render_story(data, record, seed, city, mayor, teams))
	var localized := _translated_data()
	if localized == null or record == null:
		return original
	var team_names := PackedStringArray()
	for _team in teams:
		team_names.append(TEAM_MARKER)
	var translated := (Original.render_headline(localized, record, seed, CITY_MARKER, MAYOR_MARKER, team_names) if headline_only
		else Original.render_story(localized, record, seed, CITY_MARKER, MAYOR_MARKER, team_names))
	if not translated.ok:
		return original
	# Never copy the translated grammar's choices into the city's story records.
	if not original.ok:
		original.argument = record.argument
		original.auxiliary = record.auxiliary.duplicate()
	original.ok = true
	original.error = ""
	var team := teams[translated.argument] if translated.argument >= 0 and translated.argument < teams.size() else ""
	original.headline = _restore_literals(translated.headline, city, mayor, team)
	original.article = _restore_literals(translated.article, city, mayor, team)
	return original


static func _restore_literals(value: String, city: String, mayor: String, team: String) -> String:
	for marker: String in _literal_markers:
		value = value.replace(marker, _literal_markers[marker])
	return value.replace(CITY_MARKER, city).replace(MAYOR_MARKER, mayor).replace(TEAM_MARKER, team)


static func _translated_data() -> DataUsaResource:
	if TranslationServer.get_locale().get_slice("_", 0) != "de":
		return null
	if _german != null:
		return _german
	var first := "SC2K newspaper phrase 1"
	if TranslationServer.translate(first, "original") == first:
		return null
	var data := DataUsaResource.new()
	data.bases.resize(DataUsaResource.TABLE_ENTRY_COUNT)
	data.counts.resize(DataUsaResource.TABLE_ENTRY_COUNT)
	data.offsets.resize(DataUsaResource.PHRASE_COUNT)
	data.grammar.append(0)
	for table: int in TABLES:
		data.bases[table] = TABLES[table].x
		data.counts[table] = TABLES[table].y
	for phrase in DataUsaResource.PHRASE_COUNT:
		var key := "SC2K newspaper phrase %d" % phrase
		var value := String(TranslationServer.translate(key, "original"))
		if value == key:
			continue
		var compiled := _compile(value)
		data.offsets[phrase] = data.grammar.size()
		data.grammar.append_array(compiled)
		data.grammar.append(0)
	_german = data
	return _german


static func _compile(value: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	var cursor := 0
	while cursor < value.length():
		if value.substr(cursor, 2) == "{{":
			var end := value.find("}}", cursor + 2)
			assert(end >= 0, "Unclosed newspaper substitution")
			var marker := value.substr(cursor + 2, end - cursor - 2)
			var kind := marker.get_slice(":", 0)
			if TOKENS.has(kind):
				bytes.append(TOKENS[kind])
			elif ARGUMENT_TOKENS.has(kind):
				bytes.append(ARGUMENT_TOKENS[kind])
				bytes.append(int(marker.get_slice(":", 1)))
			else:
				assert(kind == "phrase", "Unknown newspaper substitution")
				var phrase := int(marker.get_slice(":", 1))
				assert(phrase > 0 and phrase < 32)
				bytes.append(phrase)
			cursor = end + 2
		else:
			var code := value.unicode_at(cursor)
			if GERMAN_OEM.has(code):
				bytes.append(92)
				bytes.append(GERMAN_OEM[code])
			elif code >= 128:
				# The existing OEM renderer cannot represent every German glyph.
				# ASCII markers let its formatting run before Unicode is restored.
				var marker := "909%03d909" % code
				_literal_markers[marker] = String.chr(code)
				bytes.append_array(marker.to_ascii_buffer())
			else:
				if code < 32 or code == 92 or code in TOKENS.values() or code in ARGUMENT_TOKENS.values():
					bytes.append(92)
				bytes.append(code)
			cursor += 1
	return bytes


# The text tables address alternative phrases; these are not news priorities,
# simulation parameters, or story queues. All prose lives in de_original.po.
const TABLES := {
	0: Vector2i(8, 1),
	1: Vector2i(9, 7),
	2: Vector2i(16, 4),
	3: Vector2i(20, 1),
	4: Vector2i(21, 2),
	5: Vector2i(23, 2),
	6: Vector2i(25, 3),
	7: Vector2i(28, 4),
	8: Vector2i(32, 6),
	9: Vector2i(38, 3),
	10: Vector2i(41, 3),
	11: Vector2i(44, 3),
	12: Vector2i(47, 3),
	13: Vector2i(50, 1),
	14: Vector2i(51, 2),
	15: Vector2i(53, 3),
	16: Vector2i(56, 5),
	17: Vector2i(61, 5),
	18: Vector2i(66, 5),
	19: Vector2i(71, 5),
	20: Vector2i(76, 6),
	21: Vector2i(82, 5),
	22: Vector2i(87, 3),
	23: Vector2i(90, 3),
	24: Vector2i(93, 3),
	25: Vector2i(96, 2),
	26: Vector2i(98, 4),
	27: Vector2i(102, 3),
	28: Vector2i(105, 3),
	29: Vector2i(108, 3),
	30: Vector2i(111, 2),
	31: Vector2i(113, 2),
	32: Vector2i(117, 2),
	33: Vector2i(115, 2),
	34: Vector2i(119, 2),
	35: Vector2i(121, 3),
	36: Vector2i(124, 3),
	37: Vector2i(127, 3),
	38: Vector2i(130, 3),
	39: Vector2i(133, 2),
	40: Vector2i(135, 2),
	41: Vector2i(137, 1),
	42: Vector2i(138, 1),
	43: Vector2i(139, 1),
	44: Vector2i(140, 1),
	45: Vector2i(141, 23),
	46: Vector2i(164, 3),
	47: Vector2i(167, 2),
	48: Vector2i(169, 3),
	49: Vector2i(172, 3),
	50: Vector2i(175, 2),
	51: Vector2i(177, 3),
	52: Vector2i(180, 2),
	53: Vector2i(182, 2),
	54: Vector2i(184, 2),
	55: Vector2i(186, 2),
	56: Vector2i(188, 2),
	57: Vector2i(190, 2),
	58: Vector2i(192, 2),
	59: Vector2i(194, 2),
	60: Vector2i(196, 2),
	61: Vector2i(198, 4),
	62: Vector2i(202, 4),
	63: Vector2i(206, 2),
	64: Vector2i(208, 4),
	65: Vector2i(212, 2),
	66: Vector2i(214, 2),
	67: Vector2i(1, 8),
	68: Vector2i(216, 20),
	69: Vector2i(236, 21),
	70: Vector2i(257, 2),
	71: Vector2i(259, 2),
	72: Vector2i(261, 2),
	73: Vector2i(263, 2),
	74: Vector2i(265, 2),
	75: Vector2i(267, 2),
	76: Vector2i(269, 10),
	77: Vector2i(279, 10),
	78: Vector2i(289, 56),
	79: Vector2i(345, 6),
	80: Vector2i(351, 4),
	81: Vector2i(355, 12),
	82: Vector2i(367, 13),
	83: Vector2i(380, 7),
	84: Vector2i(387, 7),
	85: Vector2i(394, 7),
	86: Vector2i(401, 13),
	87: Vector2i(414, 11),
	88: Vector2i(425, 12),
	89: Vector2i(437, 11),
	90: Vector2i(448, 14),
	91: Vector2i(462, 11),
	92: Vector2i(473, 11),
	93: Vector2i(484, 16),
	94: Vector2i(500, 18),
	95: Vector2i(518, 18),
	96: Vector2i(536, 16),
	97: Vector2i(552, 16),
	98: Vector2i(568, 16),
	99: Vector2i(584, 16),
	100: Vector2i(601, 6),
	101: Vector2i(607, 20),
	102: Vector2i(627, 12),
	103: Vector2i(639, 10),
	104: Vector2i(649, 7),
	105: Vector2i(656, 7),
	106: Vector2i(663, 7),
	107: Vector2i(670, 5),
	108: Vector2i(684, 7),
	109: Vector2i(675, 9),
	110: Vector2i(691, 66),
	111: Vector2i(757, 18),
	112: Vector2i(775, 36),
	113: Vector2i(811, 13),
	114: Vector2i(824, 7),
	115: Vector2i(831, 13),
	116: Vector2i(844, 5),
	117: Vector2i(849, 18),
	118: Vector2i(867, 9),
	119: Vector2i(876, 37),
	120: Vector2i(913, 7),
	121: Vector2i(920, 8),
	122: Vector2i(928, 9),
	123: Vector2i(937, 94),
	124: Vector2i(1031, 25),
	125: Vector2i(1056, 4),
	126: Vector2i(1060, 7),
	127: Vector2i(1067, 9),
	128: Vector2i(1076, 6),
	129: Vector2i(1082, 6),
	130: Vector2i(1088, 43),
	131: Vector2i(1131, 96),
	132: Vector2i(1227, 37),
	133: Vector2i(1264, 62),
	134: Vector2i(1326, 4),
	135: Vector2i(1330, 12),
	136: Vector2i(1342, 10),
	137: Vector2i(1352, 7),
	138: Vector2i(1359, 4),
	139: Vector2i(1363, 4),
	140: Vector2i(1367, 9),
	141: Vector2i(1376, 7),
	142: Vector2i(1383, 15),
	143: Vector2i(1398, 9),
	144: Vector2i(1407, 9),
	145: Vector2i(1416, 8),
	146: Vector2i(1424, 12),
	147: Vector2i(1436, 10),
	148: Vector2i(1446, 9),
	149: Vector2i(1455, 9),
	150: Vector2i(1464, 7),
	151: Vector2i(1471, 8),
	152: Vector2i(1479, 7),
	153: Vector2i(1486, 2),
	154: Vector2i(1488, 18),
	155: Vector2i(1506, 10),
	156: Vector2i(1516, 6),
	157: Vector2i(1522, 7),
	158: Vector2i(1529, 6),
	159: Vector2i(1535, 6),
	160: Vector2i(1541, 8),
	161: Vector2i(1549, 10),
	162: Vector2i(1559, 11),
	163: Vector2i(1570, 7),
	164: Vector2i(1577, 9),
	165: Vector2i(1586, 5),
	166: Vector2i(1591, 9),
	167: Vector2i(1600, 7),
	168: Vector2i(1607, 5),
	169: Vector2i(1612, 9),
	170: Vector2i(1621, 8),
	171: Vector2i(1629, 4),
	172: Vector2i(1633, 7),
	173: Vector2i(1640, 12),
	174: Vector2i(1652, 6),
	175: Vector2i(1658, 24),
	176: Vector2i(1682, 10),
	177: Vector2i(1692, 9),
	178: Vector2i(1701, 7),
	179: Vector2i(1708, 24),
	180: Vector2i(1732, 5),
}
