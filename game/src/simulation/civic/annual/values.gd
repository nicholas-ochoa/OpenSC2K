class_name MicrosimAnnualValues
extends MicrosimAnnualConstants


@warning_ignore_start("integer_division")


static func _budget_funding(misc: PackedByteArray, budget_id: int) -> int:
	return BinaryData.read_i32_be(
		misc, MISC_BUDGETS + budget_id * BUDGET_RECORD_SIZE + BUDGET_FUNDING
	)
