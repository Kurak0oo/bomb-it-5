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


func dispatch(instance: String, kind: StringName) -> void:
	# A copy: handlers may add or remove listeners while running, as in AS3.
	for handler: Callable in (_table.get(instance + ":" + kind, []) as Array).duplicate():
		handler.call(instance)
