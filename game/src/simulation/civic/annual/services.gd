class_name MicrosimAnnualServices
extends MicrosimAnnualValues
# update services records without changing record or random-call order


static func update_hospital(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	var health_funding := _budget_funding(annual.misc, BUDGET_HEALTH)
	_write_u16_be(annual.microsims, offset + 6, _divide_toward_zero(health_funding, 2))
	var hospital_divisor := _divide_toward_zero(_tile_count(annual.misc, TILE_HOSPITAL, annual.map_edge), 9) * 25
	hospital_divisor = maxi(hospital_divisor, 1)
	var hospital_patients: int = (
		_divide_toward_zero(_read_u32(annual.misc, MISC_NORMAL_POPULATION), hospital_divisor)
		+ (annual.random.next_u15() & 0x0f)
	)

	if hospital_patients > 1000:
		hospital_patients = (annual.random.next_u15() & 0x7f) + 1000

	var hospital_capacity := _population_cap(annual.misc, _to_i16(hospital_patients), 30, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 2, hospital_capacity)
	var hospital_quality: int = (
		health_funding
		+ (annual.random.next_u15() & 0x07)
		+ int(annual.microsims[offset + 1]) * 2
		- 24
	)
	hospital_quality = maxi(hospital_quality, 0)
	var hospital_staff := _population_cap(annual.misc, _to_i16(hospital_quality), 120, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 4, hospital_staff)
	annual.microsims[offset + 1] = _service_score(hospital_capacity * 10, hospital_staff, 5)
	annual.counts.hospital += 1


static func update_police_station(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	var police_funding := _budget_funding(annual.misc, BUDGET_POLICE)
	annual.microsims[offset + 1] = police_funding & 0xff
	_write_u16_be(
		annual.microsims,
		offset + 2,
		_population_cap(annual.misc, _to_i16(police_funding * 2), 90, annual.map_edge)
	)
	var police_count := maxi(_tile_count(annual.misc, TILE_POLICE_STATION, annual.map_edge), 1)
	var crime_per_station := _divide_toward_zero(
		_read_u32(annual.misc, MISC_CITY_CRIME), police_count
	)
	_write_u16_be(annual.microsims, offset + 4, crime_per_station)
	var arrest_divisor := maxi(5 - _read_u32(annual.misc, MISC_PRISON_BONUS), 1)
	var arrests: int = (
		(annual.random.next_u15() & 0x0f)
		+ _divide_toward_zero(crime_per_station, arrest_divisor)
	)
	_write_u16_be(annual.microsims, offset + 6, arrests)
	annual.old_arrests = mini(annual.old_arrests + (arrests & 0xffff), 0xffff)
	annual.counts.police += 1


static func update_fire_station(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	var fire_funding := _budget_funding(annual.misc, BUDGET_FIRE)
	annual.microsims[offset + 1] = fire_funding & 0xff
	var fire_capacity := _population_cap(
		annual.misc, _to_i16(_divide_toward_zero(fire_funding, 2)), 70, annual.map_edge
	)
	_write_u16_be(annual.microsims, offset + 2, fire_capacity)
	_write_u16_be(annual.microsims, offset + 4, ((fire_capacity & 0xffff) >> 4) + 1)
	_write_u16_be(annual.microsims, offset + 6, (annual.random.next_u15() % 20) + 2)
	annual.counts.fire += 1


static func update_school(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	var school_funding := _budget_funding(annual.misc, BUDGET_SCHOOL)
	var school_funding_quarter := _divide_toward_zero(school_funding, 4)
	_write_u16_be(annual.microsims, offset + 6, school_funding_quarter)

	if (school_funding_quarter & 0xffff) < 20:
		annual.news_items.append({"type": NEWS_EDUCATION, "argument": 0})

	var school_count := maxi(
		_divide_toward_zero(_tile_count(annual.misc, TILE_SCHOOL, annual.map_edge), 9), 1
	)
	var school_students: int = (
		_divide_toward_zero(
			_raw_population(annual.misc, 1) + _raw_population(annual.misc, 2), school_count
		)
		+ (annual.random.next_u15() & 0x0f)
	)

	if school_students > 1500:
		school_students = (annual.random.next_u15() & 0xff) + 1500

	var school_capacity := _population_cap(annual.misc, _to_i16(school_students), 20, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 2, school_capacity)
	var school_quality: int = (
		(annual.random.next_u15() & 0x07)
		+ _divide_toward_zero(school_funding * 6, 10)
		+ int(annual.microsims[offset + 1])
		- 12
	)
	school_quality = maxi(school_quality, 0)
	var school_staff := _population_cap(annual.misc, _to_i16(school_quality), 100, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 4, school_staff)
	var school_score := _service_score(school_capacity, school_staff, 3, 15, 52)
	annual.microsims[offset + 1] = school_score
	annual.low_school_score = annual.low_school_score or school_score < 4
	annual.counts.school += 1


static func update_prison(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	var prison_divisor := maxi(annual.prison_count, 1)
	var prisoners := (
		_read_u16_be(annual.microsims, offset + 2)
		- _divide_toward_zero(_read_u16_be(annual.microsims, offset + 2), 4)
		+ _divide_toward_zero(_read_u32(annual.misc, MISC_OLD_ARRESTS), prison_divisor)
	)

	if prisoners > 10000:
		prisoners = (annual.random.next_u15() & 0x3ff) + 10000

	_write_u16_be(
		annual.microsims, offset + 2, _population_cap(annual.misc, _to_i16(prisoners), 20, annual.map_edge)
	)
	var police_funding := _budget_funding(annual.misc, BUDGET_POLICE)
	_write_u16_be(
		annual.microsims,
		offset + 4,
		_population_cap(annual.misc, _to_i16(police_funding * 3), 120, annual.map_edge)
	)
	var prison_stat := _divide_toward_zero(prisoners, 100)
	_write_u16_be(annual.microsims, offset + 6, prison_stat)
	annual.prison_population += _to_i16(prison_stat)

	if not annual.city.document.is_extended():
		annual.prison_population &= 0xffff

	if prison_stat < 91:
		annual.microsims[offset + 1] = 0
	else:
		var prison_range := (
			prison_stat - 90 + _divide_toward_zero(100 - police_funding, 10)
		)
		annual.microsims[offset + 1] = annual.random.next_u15() % prison_range

	annual.counts.prison += 1


static func update_college(annual: MicrosimAnnualContext, record_id: int, offset: int) -> void:
	if annual.random == null:
		annual.random_records_pending += 1
		return

	var college_funding := _budget_funding(annual.misc, BUDGET_COLLEGE)
	_write_u16_be(annual.microsims, offset + 6, college_funding)
	var college_count := maxi(
		_divide_toward_zero(_tile_count(annual.misc, TILE_COLLEGE, annual.map_edge), 16), 1
	)
	var college_students: int = (
		_divide_toward_zero(_raw_population(annual.misc, 3), college_count)
		+ (annual.random.next_u15() & 0x1f)
	)

	if college_students > 5000:
		college_students = (annual.random.next_u15() & 0x1ff) + 5000

	var college_capacity := _population_cap(annual.misc, _to_i16(college_students), 30, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 2, college_capacity)
	var college_quality: int = (
		(annual.random.next_u15() & 0x0f)
		+ college_funding * 2
		+ int(annual.microsims[offset + 1]) * 4
		- 48
	)
	college_quality = maxi(college_quality, 0)
	var college_staff := _population_cap(annual.misc, _to_i16(college_quality), 100, annual.map_edge)
	_write_u16_be(annual.microsims, offset + 4, college_staff)
	annual.microsims[offset + 1] = _service_score(college_capacity * 4, college_staff, 5)
	annual.counts.college += 1
