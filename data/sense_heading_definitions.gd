class_name SenseHeadingDefinitions

const MAX_LEVEL: int = 60
const CAP_AT_MAX: int = 200

static func get_cap(level: int) -> int:
	@warning_ignore("integer_division")
	return max(1, int(CAP_AT_MAX * level / MAX_LEVEL))

static func get_starting_value() -> int:
	return get_cap(1)
