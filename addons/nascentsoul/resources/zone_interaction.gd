class_name ZoneInteraction extends Resource

# --- 配置参数 ---
@export_group("Gestures")
@export var drag_enabled: bool = true
@export var drag_threshold: float = 5.0 # 像素
@export var long_press_enabled: bool = false
@export var long_press_time: float = 0.5 # 秒

# --- 内部状态 ---
var _pressed_item: Control = null
var _pressed_pos: Vector2 = Vector2.ZERO
var _is_pressed: bool = false
var _has_dragged: bool = false
var _long_press_timer: Timer = null

# --- 核心入口 ---
func register_item(zone: Node, item: Control):
	if item.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		item.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# 使用 Callable.bind 传递上下文，避免匿名函数
	if not item.mouse_entered.is_connected(_on_item_mouse_entered):
		item.mouse_entered.connect(_on_item_mouse_entered.bind(zone, item))
	if not item.mouse_exited.is_connected(_on_item_mouse_exited):
		item.mouse_exited.connect(_on_item_mouse_exited.bind(zone, item))

func handle_input(zone: Node, item: Control, event: InputEvent):
	if event is InputEventMouseButton:
		_handle_mouse_button(zone, item, event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(zone, item, event)

# --- 内部逻辑 ---

func _handle_mouse_button(zone: Node, item: Control, event: InputEventMouseButton):
	# 左键处理
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# --- 按下 ---
			_is_pressed = true
			_has_dragged = false
			_pressed_item = item
			_pressed_pos = event.global_position
			
			if long_press_enabled:
				_start_long_press_timer(zone, item)
				
		else:
			# --- 松开 ---
			_stop_long_press_timer()
			
			if _is_pressed:
				_is_pressed = false
				
				if not _has_dragged:
					if event.double_click:
						# 编译期检查：直接调用信号对象的 emit
						zone.item_double_clicked.emit(item)
					else:
						zone.item_clicked.emit(item)
	
	# 右键处理 (松开时触发)
	elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		zone.item_right_clicked.emit(item)

func _handle_mouse_motion(zone: Node, item: Control, event: InputEventMouseMotion):
	if _is_pressed and not _has_dragged:
		if event.global_position.distance_to(_pressed_pos) > drag_threshold:
			_stop_long_press_timer()
			
			if drag_enabled and not ZoneDragContext.is_dragging:
				_has_dragged = true
				_is_pressed = false
				
				var drag_items: Array[Control] = [item]
				zone.start_drag(drag_items)

# --- Hover 处理 ---
func _on_item_mouse_entered(zone: Node, item: Control):
	if not ZoneDragContext.is_dragging:
		zone.item_hover_entered.emit(item)

func _on_item_mouse_exited(zone: Node, item: Control):
	if not ZoneDragContext.is_dragging:
		zone.item_hover_exited.emit(item)

# --- 长按计时器 ---
func _start_long_press_timer(zone: Node, item: Control):
	if _long_press_timer == null:
		_long_press_timer = Timer.new()
		_long_press_timer.one_shot = true
		zone.add_child(_long_press_timer)
		_long_press_timer.timeout.connect(_on_long_press_timeout.bind(zone, item))
	
	# 确保 Timer 在树上
	if _long_press_timer.get_parent() != zone:
		if _long_press_timer.get_parent(): _long_press_timer.get_parent().remove_child(_long_press_timer)
		zone.add_child(_long_press_timer)
		
	_long_press_timer.wait_time = long_press_time
	_long_press_timer.start()

func _stop_long_press_timer():
	if is_instance_valid(_long_press_timer):
		_long_press_timer.stop()

func _on_long_press_timeout(zone: Node, item: Control):
	if _is_pressed and not _has_dragged:
		_is_pressed = false
		zone.item_long_pressed.emit(item)
