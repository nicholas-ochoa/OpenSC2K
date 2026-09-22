class_name BudgetAdvice
extends RefCounted


@warning_ignore_start("integer_division")

const Tiles = preload("res://src/tools/shared/building_tile_ids.gd")

const ADVICE: Array[String] = [
	"I have no advice at this time.",
	"We should float a bond to pay for city expansion.",
	"Rates are good right now.  Float a bond to take advantage.",
	"These outstanding bonds are killing us.  Raise taxes to pay them off.",
	"Cut back on City Services to cover the budget deficit.",
	"I'm proud to report that crime is at an all time low.",
	"Our crime rate is comparable to the national average.",
	"Crime is out of control.  We need more police stations.",
	"Our fire coverage is excellent.",
	"Our fire response is adequate.",
	"This city needs more firemen.",
	"You should lower taxes to encourage growth.",
	"Let's raise taxes to increase total funds.",
	"Cut back on services until our funds increase.",
	"The people are asking for a pollution ordinance.",
	"The power plants are overworked.  Let's push energy conservation.",
	"A neighborhood watch program would take a bite out of crime.",
	"We need an Anti-Drug campaign to help our kids.",
	"Legalized Gambling has attracted an upleasant element.",
	"You should drop the 1% income tax to give Residents a break.",
	"You should drop the 1% sales tax to give Commerce a break.",
	"Hospital services are trim, efficient and responsive.",
	"We could use more hospitals.",
	"A public smoking ban would benefit everyone.",
	"General CPR training will assuredly save lives.",
	"While expensive, Free Clinics will make you popular.",
	"Current health care is adequate to our needs.",
	"Educational services are adequate to our city's need.",
	"We need more adequately funded grade schools.",
	"We need more adequately funded colleges.",
	"YOU CAN'T CUT BACK ON FUNDING!  YOU WILL REGRET THIS!",
	"The transit lanes are inadequate.  Float a bond and build more.",
	"We have too many roads.  Remove some to save on maintenance.",
]


static func select(city: CityState, report: BudgetReport, advisor: int, random: SimRandom, power_usage: int) -> int:
	var doc := city.document
	var population := doc.misc_u32(Sc2MiscLayout.NORMAL_POPULATION)
	var flags := doc.misc_u32(Sc2MiscLayout.ORDINANCES)
	var demand := PackedInt32Array()

	for index in 3:
		demand.append(_signed_word(doc.misc_i32(Sc2MiscLayout.DEMAND + index * 4)))

	var crime := _graph(city, 7)
	var choice := 0

	match advisor:
		0:
			var total := demand[0] + demand[1] + demand[2]
			if total < -666:
				choice = 11
			elif (city.funds() & 0xffffffff) < population:
				choice = 12 if total >= 667 else 13
		1:
			if not flags & OrdinanceIds.POLLUTION_CONTROLS_MASK and _graph(city, 5) > 30:
				choice = 14
			elif not flags & OrdinanceIds.ENERGY_CONSERVATION_MASK and power_usage > 98:
				choice = 15
			elif crime > 30:
				if not flags & OrdinanceIds.NEIGHBORHOOD_WATCH_MASK:
					choice = 16
				elif not flags & OrdinanceIds.ANTI_DRUG_MASK:
					choice = 17
				elif flags & 4:
					choice = 18
			elif flags & 2 and demand[0] < -666:
				choice = 19
			elif flags & 1 and demand[1] < -666:
				choice = 20
		2:
			var denominator := (doc.misc_u32(Sc2MiscLayout.CITY_VALUE) + 1) & 0xffffffff
			var credit := _signed_word(((doc.misc_u32(Sc2MiscLayout.BONDS) * 25000) & 0xffffffff) / maxi(denominator, 1))
			if city.funds() < -1000:
				choice = 1
			elif city.funds() < 0:
				choice = 4
			elif credit + _signed_word(doc.misc_u32(Sc2MiscLayout.NATIONAL_FEDERAL_RATE)) + 1 < 4:
				choice = 2
			elif report.estimated_raw[4] > BudgetReport.wrap_i32(report.estimated_raw[0] + report.estimated_raw[1] + report.estimated_raw[2]):
				choice = 3
		3:
			choice = 5
			if crime > 40:
				choice = 7
			elif crime > 30 and not flags & OrdinanceIds.NEIGHBORHOOD_WATCH_MASK:
				choice = 16
			elif crime > 19:
				choice = 6
		4, 5:
			var health := advisor == 5
			var tiles := _signed_word(doc.misc_u32(Sc2MiscLayout.TILE_COUNTS + (Tiles.HOSPITAL if health else Tiles.FIRE_STATION) * 4))
			var capacity := BudgetReport.wrap_i32((tiles * (250 if health else 150) / 9) * report.funding[7 if health else 6]) & 0xffffffff
			var comfortable := (BudgetReport.wrap_i32(capacity * 2) / 3) & 0xffffffff
			if capacity < population:
				choice = 22 if health else 10
			elif population < comfortable:
				choice = 21 if health else 8
			elif not health:
				choice = 9
			else:
				var selected := random.next_u15() % 3
				choice = 26 if flags & [OrdinanceIds.PUBLIC_SMOKING_BAN_MASK, OrdinanceIds.CPR_TRAINING_MASK, OrdinanceIds.FREE_CLINICS_MASK][selected] else 23 + selected
		6:
			var schools := _signed_word(doc.misc_u32(Sc2MiscLayout.TILE_COUNTS + Tiles.SCHOOL * 4))
			var colleges := _signed_word(doc.misc_u32(Sc2MiscLayout.TILE_COUNTS + Tiles.COLLEGE * 4))
			var school_capacity := BudgetReport.wrap_i32((schools * 15 / 9) * report.funding[8]) & 0xffffffff
			var college_capacity := BudgetReport.wrap_i32((colleges * 50 / 16) * report.funding[9]) & 0xffffffff
			if school_capacity < ((doc.misc_u32(Sc2MiscLayout.POPULATION_TABLE + 12) + doc.misc_u32(Sc2MiscLayout.POPULATION_TABLE + 24)) & 0xffffffff):
				choice = 28
			elif college_capacity < doc.misc_u32(Sc2MiscLayout.POPULATION_TABLE + 36):
				choice = 29
			else:
				choice = 27
		7:
			var count := 0
			var funding := 0
			for id in range(10, 16):
				count = (count + report.current[id]) & 0xffffffff
				funding = BudgetReport.wrap_i32(funding + report.funding[id])
			if funding < 600:
				choice = 30
			elif count < population / 100:
				choice = 31
			elif count > population / 10:
				choice = 32

	return choice


static func _graph(city: CityState, id: int) -> int:
	var series := city.graph_series(id)
	return BudgetReport.wrap_i32(series.year[0]) if series != null else 0


static func _signed_word(value: int) -> int:
	var low := value & 0xffff
	return low - 0x10000 if low & 0x8000 else low
