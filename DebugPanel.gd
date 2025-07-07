extends VBoxContainer

@onready var FPSLabel = $FPSLabel

func _process(delta: float) -> void:
	FPSLabel.text = "fps: " + str(Engine.get_frames_per_second())
