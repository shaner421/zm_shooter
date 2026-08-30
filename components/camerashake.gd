extends Camera3D

## Handheld camera shake settings
@export_group("Handheld Shake")
@export var shake_intensity: float = 0.002
@export var rotation_intensity: float = 0.001
@export var shake_speed: float = 1.5

var _noise: FastNoiseLite
var _time: float = 0.0
var _base_position: Vector3
var _base_rotation: Vector3

func _ready() -> void:
	_base_position = position
	_base_rotation = rotation

	_noise = FastNoiseLite.new()
	_noise.seed = randi()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.5

func _process(delta: float) -> void:
	_time += delta * shake_speed

	# Position offset
	var pos_offset = Vector3(
		_noise.get_noise_2d(_time * 100, 0) * shake_intensity,
		_noise.get_noise_2d(0, _time * 100) * shake_intensity,
		_noise.get_noise_2d(_time * 50, _time * 50) * shake_intensity * 0.5
	)

	# Rotation offset (subtle tilt)
	var rot_offset = Vector3(
		_noise.get_noise_2d(_time * 80, 200) * rotation_intensity,
		_noise.get_noise_2d(200, _time * 80) * rotation_intensity,
		_noise.get_noise_2d(_time * 60, 300) * rotation_intensity * 0.5
	)

	position = _base_position + pos_offset
	rotation = _base_rotation + rot_offset
