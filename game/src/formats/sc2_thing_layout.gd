class_name Sc2ThingLayout
extends RefCounted
## XTHG records keep the same low-plane field order in SCDH and SCLG.

const RECORD_SIZE := 12
const ORIGINAL_COUNT := 40
const ORIGINAL_SIZE := RECORD_SIZE * ORIGINAL_COUNT

enum Field { TYPE, DIRECTION, STATE, X, Y, Z, PX, PY, DX, DY, LABEL, GOAL }
enum Type {
	NONE, AIRPLANE, HELICOPTER, SHIP, BULLDOZER, MONSTER, EXPLOSION, POLICE,
	FIRE, SAILBOAT, TRAIN_ENGINE, TRAIN_CAR, SUBWAY_ENGINE, SUBWAY_CAR,
	MILITARY, TORNADO, MAXIS_MAN,
}
# These high-plane bytes store coordinates plus one for extended ships.
enum ShipHomeField { X_LOW = 0, X_HIGH = 1, Y_LOW = 2, Y_HIGH = 5 }
