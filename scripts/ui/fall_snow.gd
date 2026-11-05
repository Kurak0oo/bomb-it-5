extends Node2D
## Port of `zlong.bombit5.ui.FallSnow`: the confetti a GAME_WIN drops over the stage
## (`PlayerGameOver.initView`: `new FallSnow(_root.stage)`). Method and field names follow
## the AS3; each method cites its source.
##
## - Art: every frame of the library clip `fallSnow` drawn into a 25x25 BitmapData
##   (`init`), from the local pack (original/screens/<screen>/manifest.json `effects`,
##   written by tools/convert/record_screen.py art). Without the pack each frame is a 25x25
##   outline, so placement and motion still show.
## - `Math.random` is the Flash RNG port (scripts/simulation/avm_random.gd), the app's
##   `math_random`, so the draws follow the original's formulas and order.
## - The stage is the generated screen (scripts/ui/swf_screen.gd), in stage units. Its
##   SWF frame clock drives `ENTER_FRAME`; the 300 ms `Timer` runs on the same clock, as the
##   reference player's timers do (Ruffle `Timers::update_timers`: after each frame the
##   clock advances by 1000/35 ms in whole microseconds and a timer fires once its tick
##   time is passed). In play the clock follows wall time at 35 fps, as Flash's timers do.
## - A Bitmap is a Sprite2D at the Bitmap's registration point (top left), with
##   `smoothing` as linear filtering; `x` and `y` are stored in twips, truncated, as Flash
##   (Ruffle `Twips::from_pixels`) stores them. ColorTransform.color (multipliers 0, offsets
##   the colour) is drawn by a shader that keeps the bitmap's alpha and takes the colour.
##   `cacheAsBitmap` and `pixelSnapping = "auto"` change nothing for rotated, scaled bitmaps.
##
## The FallSnow Sprite itself is never on the AS3 display list; here it is a child of the
## stage that draws nothing, so it receives frames.

const AvmRandom = preload("res://scripts/simulation/avm_random.gd")
const PACK := "res://original/screens/%s/manifest.json"
const FPS := 35.0
## Ruffle `Timers::TIMER_SCALE`: timer times are kept in microseconds.
const TIMER_SCALE := 1000.0
const COLOR_SHADER := preload("res://scripts/ui/swf_color_offset.gdshader")

var _myTimer: Dictionary
var _mainContainer: Node2D
var _container: Node2D
var _snowMcArr: Array = []
var _directArr: Array
var _colorArr: Array
var _max := 100
var _snow: Array = []  # the `fallSnow` clip's frames (images)
var _snowArr: Array = []
var _snowIndexArr: Dictionary = {}
var _totalFrame: int
var _random: AvmRandom
var _materials: Dictionary = {}  # one ColorTransform per colour
var _frames_seen := 0
var _made := 0


## `FallSnow(param1:DisplayObjectContainer)`: `random` is the app's `Math.random`.
func _init(stage: Node2D, random: AvmRandom) -> void:
	name = "FallSnow"
	_mainContainer = stage
	_random = random
	init()


## `init`
func init() -> void:
	_container = Node2D.new()
	_container.name = "FallSnowContainer"
	_snowMcArr = []
	_directArr = [1, -1]
	_colorArr = [10089983, 16777113, 16711782, 6736998, 26367, 11796326]
	_mainContainer.add_child(_container)  # this._mainContainer.stage.addChild(this._container)
	# this._myTimer = new Timer(300); addEventListener(TIMER, timerHandle); start()
	_myTimer = {"delay": 300, "now": 0, "tick_time": int(300 * TIMER_SCALE), "running": true}
	_snow = _fall_snow_frames()  # this._snow = new fallSnow()
	_snowArr = []
	_snowIndexArr = {}
	# Each frame of the clip drawn into BitmapData(25, 25, true, 0) at matrix scale(1, 1).
	for frame: Image in _snow:
		_snowArr.append(ImageTexture.create_from_image(frame))
	_totalFrame = _snowArr.size()
	# this.addEventListener(Event.ENTER_FRAME, this.enterFrameHandle): the stage's frames.
	_frames_seen = int(_mainContainer.get("frames_since_created"))
	_mainContainer.add_child(self)


## The stage's SWF frames since the last call: `ENTER_FRAME`, then the timers (the
## reference player's `run_frame` then `update_timers`).
func _process(_delta: float) -> void:
	var frames := int(_mainContainer.get("frames_since_created"))
	while _frames_seen < frames:
		_frames_seen += 1
		enterFrameHandle()
		_update_timer()


func _update_timer() -> void:
	if not _myTimer.get("running", false): return
	_myTimer.now += int(1000.0 / FPS * TIMER_SCALE)
	while _myTimer.running and _myTimer.tick_time < _myTimer.now:
		_myTimer.tick_time += int(_myTimer.delay * TIMER_SCALE)
		timerHandle()


## `onadded` (registered nowhere in the AS3)
func onadded() -> void:
	pass


## `timerHandle`
func timerHandle() -> void:
	creatSnow()


## `creatSnow`
func creatSnow() -> void:
	if _snowMcArr.size() < _max:
		var bitmap := Sprite2D.new()  # new Bitmap(_snowArr[0].clone())
		bitmap.texture = _snowArr[0]
		bitmap.centered = false
		_snowIndexArr[bitmap] = 0
		bitmap.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smoothing = true
		var color: int = _colorArr[floori(_random.random() * _colorArr.size())]
		bitmap.material = _color_transform(color)  # transform.colorTransform (ColorTransform.color)
		_made += 1
		bitmap.name = "Snow%d" % _made
		bitmap.set_meta("swf_path", "/FallSnow#%d" % _made)
		bitmap.set_meta("swf_kind", "bitmap")
		bitmap.set_meta("swf_effect", "FallSnow")
		bitmap.set_meta("swf_color_transform", {"mult": [0.0, 0.0, 0.0, 1.0],
			"add": [(color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF, 0]})
		_set_x(bitmap, int(_random.random() * 710))
		_set_y(bitmap, int(_random.random() * 20))
		bitmap.rotation_degrees = _random.random() * 180
		var scale_value := _random.random()
		bitmap.scale = Vector2(scale_value, scale_value)  # scaleX, scaleY
		_mainContainer.add_child(bitmap)
		_snowMcArr.append(bitmap)


## `enterFrameHandle`. AS3 `for each` walks the array by index, so a bitmap removed here
## lets the next one skip this frame, as in the original.
func enterFrameHandle() -> void:
	var i := 0
	while i < _snowMcArr.size():
		var bitmap: Sprite2D = _snowMcArr[i]
		i += 1
		_set_y(bitmap, bitmap.position.y + 1)  # ++_loc3_.y
		var step := _random.random() * 2
		_set_x(bitmap, bitmap.position.x + step * _directArr[floori(_random.random() * _directArr.size())])
		var index: int = _snowIndexArr[bitmap]
		bitmap.texture = _snowArr[index]
		index += 1
		if index >= _totalFrame:
			index = 0
		_snowIndexArr[bitmap] = index
		if bitmap.position.y > 500 or bitmap.position.x > 710 or bitmap.position.y < 0:
			_mainContainer.remove_child(bitmap)
			bitmap.queue_free()
			_snowMcArr.remove_at(_snowMcArr.find(bitmap))
			_snowIndexArr.erase(bitmap)


## `deleSnow`
func deleSnow() -> void:
	set_process(false)  # removeEventListener(ENTER_FRAME, enterFrameHandle)
	for bitmap: Sprite2D in _snowMcArr:
		if bitmap.get_parent() != null:
			bitmap.get_parent().remove_child(bitmap)
			bitmap.queue_free()
	if _container.get_parent() == _mainContainer:
		_mainContainer.remove_child(_container)
		_container.queue_free()
	_myTimer.running = false  # _myTimer.stop()
	_myTimer = {}
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()


## `reAddDisPlay`
func reAddDisPlay() -> void:
	if _container.get_parent() == null:
		_mainContainer.add_child(_container)


## `ColorTransform.color = color`: multipliers 0, offsets the colour.
func _color_transform(color: int) -> ShaderMaterial:
	if not _materials.has(color):
		var material := ShaderMaterial.new()
		material.shader = COLOR_SHADER
		material.set_shader_parameter("offset", Vector3((color >> 16) & 0xFF, (color >> 8) & 0xFF, color & 0xFF) / 255.0)
		_materials[color] = material
	return _materials[color]


## DisplayObject `x` / `y`: kept in whole twips (1/20 unit), truncated.
static func _twips(value: float) -> float:
	return int(value * 20.0) / 20.0


func _set_x(bitmap: Sprite2D, value: float) -> void:
	bitmap.position.x = _twips(value)


func _set_y(bitmap: Sprite2D, value: float) -> void:
	bitmap.position.y = _twips(value)


## The `fallSnow` clip's frames as the 25x25 BitmapData `init` draws, from the local pack.
func _fall_snow_frames() -> Array:
	var frames := []
	var screen_name := String(_mainContainer.get("screen_name"))
	var file := PACK % screen_name
	var entry: Dictionary = {}
	if FileAccess.file_exists(file):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string(file))
		if manifest is Dictionary: entry = manifest.get("effects", {}).get("FallSnow", {})
	for frame_file in entry.get("frames", []):
		var image := Image.load_from_file(file.get_base_dir().path_join(frame_file))
		if image != null: frames.append(image)
	if frames.is_empty():
		# No pack: one outlined 25x25 frame, so the effect still shows where it runs.
		var outline := Image.create(25, 25, false, Image.FORMAT_RGBA8)
		for k in 25:
			for p in [Vector2i(k, 0), Vector2i(k, 24), Vector2i(0, k), Vector2i(24, k)]:
				outline.set_pixelv(p, Color.WHITE)
		frames.append(outline)
	return frames
