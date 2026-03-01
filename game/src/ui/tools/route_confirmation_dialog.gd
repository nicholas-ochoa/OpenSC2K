class_name RouteConfirmationDialog
extends ConfirmationDialog


func configure(
	dialog_title: String,
	prompt_text: String,
	confirm_text: String,
	cancel_text: String,
	dialog_size := Vector2i(520, 210)
) -> void:
	title = dialog_title
	dialog_text = prompt_text
	min_size = dialog_size
	exclusive = true
	get_ok_button().text = confirm_text
	get_cancel_button().text = cancel_text


func set_message(message_text: String, cancel_text := "") -> void:
	dialog_text = message_text

	if not cancel_text.is_empty():
		get_cancel_button().text = cancel_text


func show_message(message_text: String, cancel_text := "") -> void:
	set_message(message_text, cancel_text)
	popup_centered()
