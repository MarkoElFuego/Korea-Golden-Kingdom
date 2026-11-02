extends RefCounted
## Loads player-facing texts from data/text/*.csv into the TranslationServer, so tr()
## works in the game and in headless tests without editor import.
## CSV format: first row "keys,en[,ko...]", then one key per row.

const TEXT_FILE := "res://data/text/en.csv"
const LOCALE := "en"

static var _installed := false


## Reads one locale column of a CSV file as {key: text}.
static func read_csv(path: String, locale := LOCALE) -> Dictionary:
	var result := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open text file %s" % path)
		return result
	var header := file.get_csv_line()
	var column := header.find(locale)
	if column < 1:
		push_error("No '%s' column in %s" % [locale, path])
		return result
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() > column and row[0] != "":
			result[row[0]] = row[column]
	return result


## Registers the English texts once and selects English.
static func install() -> void:
	if _installed:
		return
	var translation := Translation.new()
	translation.locale = LOCALE
	var texts := read_csv(TEXT_FILE)
	for key in texts:
		translation.add_message(key, texts[key])
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale(LOCALE)
	_installed = true
