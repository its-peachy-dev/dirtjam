extends Camera3D

var target_camera_state : CameraState;
var interpolating_camera_state : CameraState;

var boost = -3.0;

var position_lerp_time = 0.2;

var rotation_lerp_time = 0.01;


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	target_camera_state = CameraState.new();
	interpolating_camera_state = CameraState.new();

	target_camera_state.SetFromTransform(self.rotation, self.position)
	interpolating_camera_state.SetFromTransform(self.rotation, self.position)

func get_input_direction() -> Vector3:
	var direction = Vector3(0, 0, 0);

	if Input.is_key_pressed(KEY_W): direction += Vector3.FORWARD;
	if Input.is_key_pressed(KEY_S): direction += Vector3.BACK;
	if Input.is_key_pressed(KEY_A): direction += Vector3.LEFT;
	if Input.is_key_pressed(KEY_D): direction += Vector3.RIGHT;
	if Input.is_key_pressed(KEY_Q): direction += Vector3.DOWN;
	if Input.is_key_pressed(KEY_E): direction += Vector3.UP;

	return direction;

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	


	var translation = get_input_direction();

	if Input.is_key_pressed(KEY_SHIFT):
		translation *= 10.0;

	translation *= pow(2.0, boost);

	target_camera_state.Translate(translation);

	var positionLerpPct = 1.0 - exp((log(1.0 - 0.99) / position_lerp_time) * delta);

	interpolating_camera_state.LerpTowards(target_camera_state, positionLerpPct, 0);

	self.position = interpolating_camera_state.GetCameraPosition()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			boost += 0.2;
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			boost -= 0.2;

	
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var mouse_movement = event.relative * get_process_delta_time()

		target_camera_state.angles += Vector3(-mouse_movement.y, -mouse_movement.x, 0.0) * 0.25

		var rotation_lerp_percent = 1.0 - exp((log(1.0 - 0.99) / rotation_lerp_time) * get_process_delta_time())

		interpolating_camera_state.LerpTowards(target_camera_state, 0, rotation_lerp_percent)

		self.rotation = interpolating_camera_state.GetEulerAngles()
