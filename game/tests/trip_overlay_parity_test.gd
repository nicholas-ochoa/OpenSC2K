extends SceneTree

const Fixtures = preload("res://tests/support/trip_overlay_fixtures.gd")
# Geometry, colors, costs and mode maps captured before the rebuild optimization.
# These generated fixtures require no original game assets.
const EXPECTED := {
	"road": "c67f6791bf6f87f4bae6ff379ea42db157f0f59065ff45c23e7a7a9d82885ef8",
	"mixed": "2d41f6ba10d7c45c2e2ea09e0b22e68c175ef434ba73caad6d41423c2f24a7fc",
	"modes": "c42113e1ac920e7131631a8da258341d2a8d4c9034c11303f8d8e676672a17fa",
	"modes_edited": "04e7766dc8ee908047122d9c66d83ad65bea2161ebd245f6ecf8fe2dfffeea87",
	"dense_128": "e18176c7e569e7865102864821b373ece65c70991cc7871da9d47b0ae25fce1d",
	"dense_512": "b21aea3c1c205aec0c709fe0f2534ae5d20b5a6191907b2cc3b172b1049576f1",
}


func _initialize() -> void:
	var overlay := TripReachOverlay.new()
	for fixture: Fixtures.Fixture in [Fixtures.road(), Fixtures.mixed(), Fixtures.modes(), Fixtures.dense(128), Fixtures.dense(512)]:
		var source := fixture.city.document.serialize(true)
		assert(source.ok)
		_check(overlay, fixture, fixture.name)
		if fixture.name == "modes":
			_check_mode_heights(overlay)
			assert(overlay.destinations.size() == 3, "One multi-tile site and two bounded neighbor destinations")
			assert(overlay.origin == overlay.access, "Missing start uses the origin")
			assert(overlay.tile_modes[Vector2i(5, 5)] == (1 << (TransportTrip.SUBWAY_MODE + 1)) - 1)
			fixture.city.set_land_altitude(5, 5, 7)
			_check(overlay, fixture, "modes_edited")
			fixture.city.set_land_altitude(5, 5, 4)
			_check(overlay, fixture, fixture.name)
		assert(fixture.city.document.serialize(true).data == source.data, "Overlay preparation does not change city bytes")
	# The same overlay must also work with a new city at the same coordinates.
	_check(overlay, Fixtures.modes(), "modes")
	print("PASS: exact Trip Reach arrays, all modes, ramps, footprints, neighbor destinations and rebuild-local state")
	quit()


func _check(overlay: TripReachOverlay, fixture: Fixtures.Fixture, expected: String) -> void:
	overlay.rebuild(fixture.city, fixture.result)
	assert(Fixtures.digest(overlay) == EXPECTED[expected], expected + " overlay geometry changed")
	assert(overlay.analysis == fixture.result, "The original analysis and summary stay attached")


func _check_mode_heights(overlay: TripReachOverlay) -> void:
	var ground := overlay.segments[0]
	for mode in range(TransportTrip.SUBWAY_MODE + 1):
		var expected := ground
		if mode in [TransportTrip.HIGHWAY_MODE, TransportTrip.BUS_HIGHWAY_MODE]:
			expected.y -= CityIsometricRenderer.ALTITUDE_STEP
		assert(overlay.segments[mode * 2] == expected, "Modes at one point keep their own heights")
	for ramp in 4:
		var first := (TransportTrip.SUBWAY_MODE + 1 + ramp * 3) * 2
		assert(overlay.segments[first] == overlay.segments[first + 2])
		assert(overlay.segments[first] == overlay.segments[first + 4], "All modes meet at one ramp height")
