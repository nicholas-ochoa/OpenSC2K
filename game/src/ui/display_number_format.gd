class_name DisplayNumberFormat
extends RefCounted


static func format(value: int) -> String:
	var negative := value < 0
	var digits := str(absi(value))
	var output := ""

	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)

	output = digits + output

	return "-" + output if negative else output
