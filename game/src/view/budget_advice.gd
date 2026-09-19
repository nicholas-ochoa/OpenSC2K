class_name BudgetAdvice
extends RefCounted


@warning_ignore_start("integer_division")

const FALLBACK := [
	"The budget looks satisfactory. Keep watching the city's needs.",
	"The city has a serious cash shortage. Consider issuing a bond.",
	"Borrowing rates are low. This is a good time to consider a bond for needed improvements.",
	"Bond payments are high compared with tax revenue. Repay bonds when funds permit.",
	"The city is short of cash. A bond can cover the deficit, but it adds interest costs.",
	"Crime is low. Police protection is working well.",
	"Crime needs attention. Review police coverage and funding.",
	"Crime is very high. The city needs stronger police protection.",
	"Fire protection has ample capacity.",
	"Fire protection is adequate. Plan for growth.",
	"The city needs more fire protection. Review stations and funding.",
	"Demand is weak. Consider reducing property taxes.",
	"Demand is strong, but cash reserves are low. Consider a tax increase.",
	"Cash reserves are low. Review taxes and spending carefully.",
	"Pollution is high. Consider pollution controls.",
	"Power use is high. Consider energy conservation.",
	"Crime is high. Consider a neighborhood watch program.",
	"Consider an anti-drug campaign to help address crime.",
	"Crime is high. Consider repealing legalized gambling.",
	"Residential demand is weak. Consider repealing the income tax.",
	"Commercial demand is weak. Consider repealing the sales tax.",
	"Health care has ample capacity.",
	"The city needs more health care. Review hospitals and funding.",
	"Consider a public smoking ban to improve health.",
	"Consider CPR training to improve health.",
	"Consider free clinics to improve access to health care.",
	"Health care is adequate. Continue to monitor demand.",
	"School and college capacity meet current needs.",
	"School capacity is too low. Review schools and education funding.",
	"College capacity is too low. Review colleges and education funding.",
	"Transport maintenance is underfunded. Restore funding to prevent decay.",
	"The transport network is small for this population. Plan more connections.",
	"The transport network is large for this population. Review maintenance costs.",
]


static func select(city: CityState, report: BudgetReport, advisor: int, random: SimRandom, power_usage: int) -> int:
	var doc := city.document
	var population := doc.misc_u32(0x102c)
	var flags := doc.misc_u32(0x0fa0)
	var demand := PackedInt32Array()

	for index in 3:
		demand.append(_signed_word(doc.misc_i32(0x0718 + index * 4)))

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
			if not flags & 0x80000 and _graph(city, 5) > 30:
				choice = 14
			elif not flags & 0x10000 and power_usage > 98:
				choice = 15
			elif crime > 30:
				if not flags & 0x800:
					choice = 16
				elif not flags & 0x200:
					choice = 17
				elif flags & 4:
					choice = 18
			elif flags & 2 and demand[0] < -666:
				choice = 19
			elif flags & 1 and demand[1] < -666:
				choice = 20
		2:
			var denominator := (doc.misc_u32(0x24) + 1) & 0xffffffff
			var credit := _signed_word(((doc.misc_u32(0x18) * 25000) & 0xffffffff) / maxi(denominator, 1))
			if city.funds() < -1000:
				choice = 1
			elif city.funds() < 0:
				choice = 4
			elif credit + _signed_word(doc.misc_u32(0x58)) + 1 < 4:
				choice = 2
			elif report.estimated_raw[4] > BudgetReport.wrap_i32(report.estimated_raw[0] + report.estimated_raw[1] + report.estimated_raw[2]):
				choice = 3
		3:
			choice = 5
			if crime > 40:
				choice = 7
			elif crime > 30 and not flags & 0x800:
				choice = 16
			elif crime > 19:
				choice = 6
		4, 5:
			var health := advisor == 5
			var tiles := _signed_word(doc.misc_u32(0x1f0 + (0xd1 if health else 0xd3) * 4))
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
				choice = 26 if flags & [0x20, 0x400, 0x40][selected] else 23 + selected
		6:
			var schools := _signed_word(doc.misc_u32(0x1f0 + 0xd6 * 4))
			var colleges := _signed_word(doc.misc_u32(0x1f0 + 0xd9 * 4))
			var school_capacity := BudgetReport.wrap_i32((schools * 15 / 9) * report.funding[8]) & 0xffffffff
			var college_capacity := BudgetReport.wrap_i32((colleges * 50 / 16) * report.funding[9]) & 0xffffffff
			if school_capacity < ((doc.misc_u32(0x7c + 12) + doc.misc_u32(0x7c + 24)) & 0xffffffff):
				choice = 28
			elif college_capacity < doc.misc_u32(0x7c + 36):
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

	return 294 + choice


static func _graph(city: CityState, id: int) -> int:
	var series := city.graph_series(id)
	return BudgetReport.wrap_i32(series.year[0]) if series != null else 0


static func _signed_word(value: int) -> int:
	var low := value & 0xffff
	return low - 0x10000 if low & 0x8000 else low
