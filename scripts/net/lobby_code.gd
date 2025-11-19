extends RefCounted
class_name LobbyCode

const DEFAULT_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const DEFAULT_LENGTH := 5

static func normalize(code: String) -> String:
	return code.strip_edges().to_upper()

static func is_valid(code: String, length := DEFAULT_LENGTH) -> bool:
	var normalized := normalize(code)
	if normalized.length() != length:
		return false
	for i in range(normalized.length()):
		var ch := normalized.substr(i, 1)
		if DEFAULT_ALPHABET.find(ch) == -1:
			return false
	return true

static func generate(length := DEFAULT_LENGTH, rng: RandomNumberGenerator = null) -> String:
	if length <= 0:
		return ""
	var generator := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		generator.randomize()
	var result := ""
	for i in length:
		var index := generator.randi_range(0, DEFAULT_ALPHABET.length() - 1)
		result += DEFAULT_ALPHABET[index]
	return result
