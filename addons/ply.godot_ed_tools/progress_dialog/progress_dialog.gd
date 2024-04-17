@tool
class_name PlyToolsProgressDialog
extends Window

@onready var _heading : Label = %Label1
@onready var _message : Label = %Label2
@onready var _progress : ProgressBar = %ProgressBar

# ----------------------------------------------------------------------------------------------------------------------

func set_heading(value: String) -> void:
	_heading.text = value

func set_message(value: String) -> void:
	_message.text = value

func set_progress(value: float) -> void:
	_progress.value = value

func close() -> void:
	queue_free()

# ----------------------------------------------------------------------------------------------------------------------
