class_name GoldenFile
## Reads committed goldens (tests/goldens), which are stored gzip-compressed: a caller
## names the logical file (`<capture>.json`, `<capture>.timeline.json`) and gets its text
## whether the file on disk is the plain `.json` or its `.json.gz` (tools/golden_io.py).


static func exists(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".gz")


static func read_text(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	var packed := FileAccess.get_file_as_bytes(path + ".gz")
	if packed.is_empty():
		push_error("GoldenFile: no golden at %s(.gz)" % path)
		return ""
	return packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()


static func load_json(path: String) -> Variant:
	return JSON.parse_string(read_text(path))
