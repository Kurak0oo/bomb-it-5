extends RefCounted
## AS3 event listeners on a generated screen's instances (`addEventListener` /
## `removeEventListener`), so ported UI code can toggle its handlers as the original does.
## Kinds follow the screen's mouse events: &"down" (MOUSE_DOWN), &"over" (MOUSE_OVER and
## ROLL_OVER), &"out" (MOUSE_OUT), &"up", &"click".

var _table := {}


func _init(screen: Node2D) -> void:
	screen.mouse_event.connect(dispatch)


func add(instance: String, kind: StringName, handler: Callable) -> void:
	var list: Array = _table.get_or_add(instance + ":" + kind, [])
	if not list.has(handler): list.append(handler)


func remove(instance: String, kind: StringName, handler: Callable) -> void:
	var list: Array = _table.get(instance + ":" + kind, [])
	list.erase(handler)


## `instance` is the address relative to the screen root; listeners on the bare instance
## name hear it too (a top-level `arcadeMode`, or `cinemaStages` inside the dropdown).
func dispatch(instance: String, kind: StringName) -> void:
	var name := instance.get_slice("/", instance.get_slice_count("/") - 1)
	# A copy: handlers may add or remove listeners while running, as in AS3.
	var handlers: Array = (_table.get(instance + ":" + kind, []) as Array).duplicate()
	if name != instance: handlers += (_table.get(name + ":" + kind, []) as Array).duplicate()
	for handler: Callable in handlers:
		handler.call(instance if _table.get(instance + ":" + kind, []).has(handler) else name)
