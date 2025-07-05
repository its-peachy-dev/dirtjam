extends Resource
class_name CameraState

var angles : Vector3;
var camera_position : Vector3;


func SetFromTransform(eulerAngles : Vector3, position : Vector3) -> void:
	angles = eulerAngles;
	camera_position = position;


func Translate(translation : Vector3) -> void:
	var rotatedTranslation = Quaternion.from_euler(angles) * translation;

	camera_position += rotatedTranslation;

func LerpTowards(target : CameraState, positionLerpPct : float, rotationLerpPct : float):
	angles = angles.lerp(target.angles, rotationLerpPct);

	camera_position = camera_position.lerp(target.camera_position, positionLerpPct);

func GetEulerAngles() -> Vector3:
	return angles;

func GetCameraPosition() -> Vector3:
	return camera_position;
