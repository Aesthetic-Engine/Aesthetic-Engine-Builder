extends RefCounted
class_name BuilderRoomLoader
## Loads and caches room JSON data from content/rooms/.
##
## Room JSON schema:
##   {
##     "id": "room_id",
##     "title": "Room Title",
##     "procedural": true,
##     "procedural_scene": "room_id",
##     "hotspots": [
##       { "id": "hs_id", "name": "Display Name", "rect": [x, y, w, h], "verbs": ["look", "use"], "tags": [] }
##     ],
##     "actions": [
##       { "verb": "look", "target": "hs_id", "then": [ { "print": "Description text." } ] }
##     ],
##     "events": [
##       { "trigger": "enter", "do": [ { "print": "You enter the room." } ] }
##     ]
##   }

var _cache: Dictionary = {}
var _rooms_dir: String = "res://content/rooms/"


func set_rooms_directory(dir: String) -> void:
	_rooms_dir = dir if dir.ends_with("/") else dir + "/"


func load_room(room_id: String) -> Dictionary:
	if _cache.has(room_id):
		return _cache[room_id]

	var path := _rooms_dir + room_id + ".json"
	if not FileAccess.file_exists(path):
		push_error("BuilderRoomLoader: Room file not found: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("BuilderRoomLoader: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}

	var data: Dictionary = json.data
	_cache[room_id] = data
	return data


func get_room_title(room_data: Dictionary) -> String:
	return room_data.get("title", "UNKNOWN ROOM")


func is_procedural(room_data: Dictionary) -> bool:
	return room_data.get("procedural", false)


func get_procedural_scene(room_data: Dictionary) -> String:
	return room_data.get("procedural_scene", "")


func get_hotspots(room_data: Dictionary) -> Array:
	return room_data.get("hotspots", [])


func get_actions(room_data: Dictionary) -> Array:
	return room_data.get("actions", [])


func get_events(room_data: Dictionary) -> Array:
	return room_data.get("events", [])


func list_room_ids() -> PackedStringArray:
	var ids: PackedStringArray = []
	var dir := DirAccess.open(_rooms_dir)
	if dir == null:
		return ids
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".json"):
			ids.append(fname.get_basename())
		fname = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids


func clear_cache() -> void:
	_cache.clear()
