extends Control

@onready var teacher_panel: VBoxContainer = $MainContent/TeacherPanel
@onready var student_panel: VBoxContainer = $MainContent/StudentPanel
@onready var teacher_btn: Button = $TopBar/RoleSwitch/TeacherBtn
@onready var student_btn: Button = $TopBar/RoleSwitch/StudentBtn
@onready var status_label: Label = $StatusLabel

var stats_hbox: HBoxContainer
var templates_list: ItemList
var generated_assignments_list: ItemList
var student_assignments_list: ItemList
var student_details: RichTextLabel

var templates_count_label: Label
var assignments_count_label: Label
var bones_count_label: Label

var current_role: String = "teacher"
var selected_template_index: int = -1
var selected_generated_assignment_index: int = -1
var selected_student_assignment_index: int = -1

var _current_template_dialog: Window = null
var _dialog_param_controls: Dictionary = {}


func _ready():
	GlobalData.templates_changed.connect(_on_templates_changed)
	GlobalData.assignments_changed.connect(_on_assignments_changed)
	GlobalData.data_loaded.connect(_on_data_loaded)

	BackendAPI.templates_received.connect(_on_templates_received)
	BackendAPI.template_created.connect(_on_template_created)
	BackendAPI.assignment_generated.connect(_on_assignment_generated)
	BackendAPI.assignments_received.connect(_on_assignments_received)
	BackendAPI.request_failed.connect(_on_request_failed)

	teacher_btn.pressed.connect(_on_teacher_btn_pressed)
	student_btn.pressed.connect(_on_student_btn_pressed)

	_build_teacher_ui()
	_build_student_ui()
	_switch_to_role("teacher")

	if GlobalData.anatomical_areas.size() > 0:
		_on_data_loaded()



# ==================== СИГНАЛЫ ====================

func _on_templates_received(templates: Array):
	GlobalData.templates = templates
	GlobalData.templates_changed.emit()

func _on_template_created(template: Dictionary):
	_show_message("Шаблон успешно сохранён!")
	if _current_template_dialog and is_instance_valid(_current_template_dialog):
		_current_template_dialog.queue_free()
		_current_template_dialog = null

func _on_assignment_generated(assignment: Dictionary):
	print(">>> DEBUG [MainUI]: Задание успешно сгенерировано")
	_show_message("Задание успешно сгенерировано!")
	BackendAPI.get_assignments()

func _on_assignments_received(assignments: Array):
	GlobalData.generated_assignments = assignments
	GlobalData.assignments_changed.emit()

func _on_request_failed(error_message: String):
	var msg = error_message
	if error_message.begins_with("{"):
		var json = JSON.new()
		if json.parse(error_message) == OK and json.data.has("detail"):
			msg = str(json.data["detail"])
	_show_message("Ошибка:\n" + msg, 650)

func _on_data_loaded():
	_refresh_teacher_lists()
	_refresh_student_list()
	_update_stats()

func _on_templates_changed():
	_refresh_teacher_lists()

func _on_assignments_changed():
	_refresh_teacher_lists()
	_refresh_student_list()


# ==================== UI ПРЕПОДАВАТЕЛЯ ====================

func _build_teacher_ui():
	for child in teacher_panel.get_children():
		child.queue_free()

	# === СТАТИСТИКА ===
	stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 15)
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	teacher_panel.add_child(stats_hbox)

	templates_count_label   = _add_stat_card("Шаблонов", "0", Color(0.2, 0.6, 0.9, 1))
	assignments_count_label = _add_stat_card("Заданий", "0", Color(0.2, 0.8, 0.4, 1))
	_add_stat_card("Типов заданий", "4", Color(0.9, 0.6, 0.2, 1))
	bones_count_label       = _add_stat_card("Костей в БД", str(GlobalData.bones.size()), Color(0.6, 0.4, 0.8, 1))

	# === КНОПКА СОЗДАНИЯ ===
	var create_btn = Button.new()
	create_btn.text = " Создать новый шаблон"
	create_btn.custom_minimum_size = Vector2(0, 45)
	create_btn.pressed.connect(_open_create_template_dialog)
	teacher_panel.add_child(create_btn)

		# === СПИСОК ШАБЛОНОВ ===
	var tmpl_label = Label.new()
	tmpl_label.text = "Мои шаблоны"
	tmpl_label.add_theme_font_size_override("font_size", 18)
	tmpl_label.add_theme_color_override("font_color", Color.BLACK)
	teacher_panel.add_child(tmpl_label)

	templates_list = ItemList.new()
	templates_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	templates_list.item_selected.connect(_on_template_selected)
	teacher_panel.add_child(templates_list)

	# Кнопки действий с шаблонами (в одну строку)
	var template_actions = HBoxContainer.new()
	template_actions.add_theme_constant_override("separation", 8)
	teacher_panel.add_child(template_actions)

	var generate_btn = Button.new()
	generate_btn.text = " Сгенерировать задание"
	generate_btn.pressed.connect(_generate_from_selected_template)
	template_actions.add_child(generate_btn)

	var view_template_btn = Button.new()
	view_template_btn.text = " Просмотреть шаблон"
	view_template_btn.pressed.connect(_view_selected_template)
	template_actions.add_child(view_template_btn)

	var edit_btn = Button.new()
	edit_btn.text = " Редактировать шаблон"
	edit_btn.pressed.connect(_edit_selected_template)
	template_actions.add_child(edit_btn)

	var delete_btn = Button.new()
	delete_btn.text = " Удалить шаблон"
	delete_btn.pressed.connect(_on_delete_selected_template)
	template_actions.add_child(delete_btn)

	# === СПИСОК СГЕНЕРИРОВАННЫХ ЗАДАНИЙ ===
	var assign_label = Label.new()
	assign_label.text = "Сгенерированные задания"
	assign_label.add_theme_font_size_override("font_size", 18)
	assign_label.add_theme_color_override("font_color", Color.BLACK)
	teacher_panel.add_child(assign_label)

	generated_assignments_list = ItemList.new()
	generated_assignments_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	generated_assignments_list.item_selected.connect(_on_generated_assignment_selected)
	teacher_panel.add_child(generated_assignments_list)

	# Кнопки действий с заданиями (точно в таком же стиле, как у шаблонов)
	var assignment_actions = HBoxContainer.new()
	assignment_actions.add_theme_constant_override("separation", 8)
	teacher_panel.add_child(assignment_actions)

	var view_assign_btn = Button.new()
	view_assign_btn.text = " Просмотреть задание"
	view_assign_btn.pressed.connect(_view_selected_generated_assignment)
	assignment_actions.add_child(view_assign_btn)

	var delete_assign_btn = Button.new()
	delete_assign_btn.text = " Удалить задание"
	delete_assign_btn.pressed.connect(_on_delete_selected_assignment)
	assignment_actions.add_child(delete_assign_btn)

	# === КНОПКИ "УДАЛИТЬ ВСЁ" (отдельной строкой внизу) ===
	var delete_all_row = HBoxContainer.new()
	delete_all_row.add_theme_constant_override("separation", 10)
	teacher_panel.add_child(delete_all_row)

	var del_all_templates = Button.new()
	del_all_templates.text = "Удалить все шаблоны"
	del_all_templates.pressed.connect(_on_delete_all_templates)
	delete_all_row.add_child(del_all_templates)

	var del_all_assigns = Button.new()
	del_all_assigns.text = "Удалить все задания"
	del_all_assigns.pressed.connect(_on_delete_all_assignments)
	delete_all_row.add_child(del_all_assigns)

	_refresh_teacher_lists()


func _add_stat_card(title: String, value: String, color: Color) -> Label:
	var card = ColorRect.new()
	card.custom_minimum_size = Vector2(160, 65)
	card.color = color

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.add_child(vbox)

	var title_l = Label.new()
	title_l.text = title
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_l.add_theme_font_size_override("font_size", 13)
	title_l.add_theme_color_override("font_color", Color.WHITE)   # белый на цветном фоне
	vbox.add_child(title_l)

	var val_l = Label.new()
	val_l.text = value
	val_l.name = "ValueLabel"
	val_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_l.add_theme_font_size_override("font_size", 22)
	val_l.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(val_l)

	stats_hbox.add_child(card)
	return val_l


func _update_stats():
	if templates_count_label:
		templates_count_label.text = str(GlobalData.templates.size())
	if assignments_count_label:
		assignments_count_label.text = str(GlobalData.generated_assignments.size())
	if bones_count_label:
		bones_count_label.text = str(GlobalData.bones.size())


# ==================== ДЕЙСТВИЯ ====================

func _on_template_selected(index: int):
	selected_template_index = index

func _on_generated_assignment_selected(index: int):
	selected_generated_assignment_index = index


func _generate_from_selected_template() -> void:
	if selected_template_index < 0 or selected_template_index >= GlobalData.templates.size():
		_show_message("Выберите шаблон из списка!")
		return
	
	var template = GlobalData.templates[selected_template_index]
	var template_id = template.get("id", -1)
	
	if template_id <= 0:
		_show_message("Ошибка: у выбранного шаблона нет корректного ID")
		return
	
	print(">>> DEBUG [MainUI]: Отправляю запрос на генерацию задания из шаблона id=", template_id)
	BackendAPI.generate_assignment(template_id)


func _view_selected_template():
	if selected_template_index < 0 or selected_template_index >= GlobalData.templates.size():
		_show_message("Выберите шаблон!")
		return
	
	var t = GlobalData.templates[selected_template_index]
	var area_name = GlobalData.get_area_name(t.get("anatomical_area_id", 0), t.get("language", "Русский"))
	var params = t.get("parameters", {})
	
	var text = ""
	text += "[b]Название:[/b] %s\n" % t.get("name", "Без названия")
	text += "[b]Тип задания:[/b] %s\n" % t.get("task_type", "")
	text += "[b]Анатомическая область:[/b] %s\n" % area_name
	text += "[b]Сложность:[/b] %d\n" % t.get("difficulty", 0)
	text += "[b]Язык:[/b] %s\n\n" % t.get("language", "Русский")
	
	text += "[b]Параметры шаблона:[/b]\n"
	
	match t.get("task_type", ""):
		"Идентификация кости":
			text += "• Количество вариантов ответа: %d\n" % params.get("num_variants", 4)
			if params.has("extra_bone_areas") and params["extra_bone_areas"].size() > 0:
				var names = []
				for aid in params["extra_bone_areas"]:
					names.append(GlobalData.get_area_name(int(aid), t.get("language", "Русский")))
				text += "• Области для лишних костей: %s\n" % ", ".join(names)
		
		"Определение ориентиров":
			text += "• Количество ориентиров для указания: %d\n" % params.get("num_landmarks", 3)
		
		"Сборка сустава":
			text += "• Использовать лишние кости: %s\n" % ("Да" if params.get("use_extra_bones", false) else "Нет")
			if params.get("use_extra_bones", false):
				text += "• Количество лишних костей: %d\n" % params.get("extra_bone_count", 2)
				if params.has("extra_bone_areas"):
					var names = []
					for aid in params["extra_bone_areas"]:
						names.append(GlobalData.get_area_name(int(aid), t.get("language", "Русский")))
					text += "• Области для лишних костей: %s\n" % ", ".join(names)
		
		"Сборка анатомической конструкции":
			text += "• Использовать лишние кости: %s\n" % ("Да" if params.get("use_extra_bones", false) else "Нет")
			if params.get("use_extra_bones", false):
				text += "• Количество лишних костей: %d\n" % params.get("extra_bone_count", 3)
				if params.has("extra_bone_areas"):
					var names = []
					for aid in params["extra_bone_areas"]:
						names.append(GlobalData.get_area_name(int(aid), t.get("language", "Русский")))
					text += "• Области для лишних костей: %s\n" % ", ".join(names)
			text += "• Использовать дополнительные области: %s\n" % ("Да" if params.get("use_additional_areas", false) else "Нет")
	
	_show_message(text, 680)


func _edit_selected_template():
	if selected_template_index < 0:
		_show_message("Выберите шаблон!")
		return
	var template = GlobalData.templates[selected_template_index]
	_open_create_template_dialog(template)


func _view_selected_generated_assignment():
	if selected_generated_assignment_index < 0 or selected_generated_assignment_index >= GlobalData.generated_assignments.size():
		_show_message("Выберите задание!")
		return
	
	var a = GlobalData.generated_assignments[selected_generated_assignment_index]
	var lang = a.get("language", "Русский")
	var area_name = GlobalData.get_area_name(a.get("anatomical_area_id", 0), lang)
	var d = a.get("data", {})
	
	var text = ""
	text += "[b]%s[/b]\n" % a.get("task_type", "")
	text += "Область: %s | Сложность: %d | Язык: %s\n" % [area_name, a.get("difficulty", 0), lang]
	text += "Создано: %s\n\n" % a.get("created_at", "").substr(0, 19).replace("T", " ")
	
	text += "[b]Содержание задания:[/b]\n"
	
	match a.get("task_type", ""):
		"Идентификация кости":
			text += "• Целевая кость: %s (ID: %d)\n" % [d.get("target_bone_name", ""), d.get("target_bone_id", 0)]
			if d.has("options"):
				text += "• Варианты ответов:\n"
				for opt in d["options"]:
					text += "   - %s\n" % opt.get("name", "")
		
		"Определение ориентиров":
			text += "• Кость: %s\n" % d.get("target_bone_name", "")
			if d.has("landmarks"):
				text += "• Ориентиры для указания:\n"
				for lm in d["landmarks"]:
					text += "   - %s\n" % lm.get("name_ru", "")
		
		"Сборка сустава":
			text += "• Сустав: %s\n" % d.get("joint_name", "")
			text += "• Кости для сборки: %s\n" % str(d.get("target_bone_ids", []))
			if d.has("extra_bone_ids") and d["extra_bone_ids"].size() > 0:
				text += "• Лишние кости: %s\n" % str(d["extra_bone_ids"])
			text += "• Правильные соединения: %s\n" % str(d.get("correct_connections", []))
		
		"Сборка анатомической конструкции":
			text += "• Конструкция: %s\n" % d.get("structure_name", "")
			text += "• Кости для сборки: %s\n" % str(d.get("target_bone_ids", []))
			if d.has("extra_bone_ids") and d["extra_bone_ids"].size() > 0:
				text += "• Лишние кости: %s\n" % str(d["extra_bone_ids"])
			text += "• Правильные соединения: %s\n" % str(d.get("correct_connections", []))
	
	_show_message(text, 750)


# ==================== СТУДЕНТ ====================

func _build_student_ui():
	for child in student_panel.get_children():
		child.queue_free()
	
	var header = Label.new()
	header.text = "Режим студента — Доступные задания"
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color.BLACK)   # ← ЧЁРНЫЙ
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	student_panel.add_child(header)
	
	student_assignments_list = ItemList.new()
	student_assignments_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	student_assignments_list.item_selected.connect(_on_student_assignment_selected)
	student_panel.add_child(student_assignments_list)
	
	var details_label = Label.new()
	details_label.text = "Информация о задании:"
	details_label.add_theme_color_override("font_color", Color.BLACK)   # ← ЧЁРНЫЙ
	student_panel.add_child(details_label)
	
	student_details = RichTextLabel.new()
	student_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	student_details.bbcode_enabled = true
	student_details.add_theme_color_override("default_color", Color.BLACK)   # ← ЧЁРНЫЙ
	student_panel.add_child(student_details)
	
	var start_btn = Button.new()
	start_btn.text = " Начать задание"
	start_btn.pressed.connect(_start_assignment_stub)
	student_panel.add_child(start_btn)
	
	_refresh_student_list()


func _on_student_assignment_selected(index: int):
	selected_student_assignment_index = index
	if index < 0 or index >= GlobalData.generated_assignments.size():
		return
	
	var a = GlobalData.generated_assignments[index]
	var lang = a.get("language", "Русский")
	var area_name = GlobalData.get_area_name(a.get("anatomical_area_id", 0), lang)
	
	var txt = "[b]%s[/b]\nОбласть: %s | Сложность: %d\n\nНажмите «Начать задание»." % [
		a.get("task_type", ""), area_name, a.get("difficulty", 1)
	]
	student_details.text = txt


func _start_assignment_stub():
	if selected_student_assignment_index < 0:
		_show_message("Выберите задание!")
		return
	_show_message("Визуализатор пока не подключён.\n\nЗдесь в будущем будет открываться 3D-сцена.")


func _refresh_student_list():
	if not student_assignments_list: return
	student_assignments_list.clear()
	
	for i in range(GlobalData.generated_assignments.size()):
		var a = GlobalData.generated_assignments[i]
		var lang = a.get("language", "Русский")
		var area_name = GlobalData.get_area_name(a.get("anatomical_area_id", 0), lang)
		
		var display = "[%s] %s | Сложн. %d" % [
			a.get("task_type", "Задание"),
			area_name,
			a.get("difficulty", 1)
		]
		student_assignments_list.add_item(display)


# ==================== ВСПОМОГАТЕЛЬНЫЕ ====================

func _refresh_teacher_lists():
	if templates_list:
		templates_list.clear()
		for i in range(GlobalData.templates.size()):
			var t = GlobalData.templates[i]
			var area_name = GlobalData.get_area_name(t.get("anatomical_area_id", 0), t.get("language", "Русский"))
			var display = "[%s] %s | %s | Сложн. %d" % [
				t.get("task_type", "???"),
				t.get("name", "Без названия"),
				area_name,
				t.get("difficulty", 0)
			]
			templates_list.add_item(display)
	
	if generated_assignments_list:
		generated_assignments_list.clear()
		for i in range(GlobalData.generated_assignments.size()):
			var a = GlobalData.generated_assignments[i]
			var area_name = GlobalData.get_area_name(a.get("anatomical_area_id", 0), a.get("language", "Русский"))
			var display = "[%s] %s | %s" % [
				a.get("task_type", "Задание"),
				area_name,
				a.get("created_at", "").substr(0, 16).replace("T", " ")
			]
			generated_assignments_list.add_item(display)
	
	_update_stats()


func _show_message(msg: String, width: int = 550):
	var dialog = AcceptDialog.new()
	dialog.dialog_text = msg
	dialog.size.x = width
	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


# ==================== УДАЛЕНИЕ ====================

func _on_delete_selected_template():
	if selected_template_index < 0:
		_show_message("Выберите шаблон!")
		return
	var template = GlobalData.templates[selected_template_index]
	_show_confirmation_dialog(
		"Удалить шаблон «%s»?" % template.get("name", ""),
		func(): _do_delete_template(template.get("id", -1))
	)

func _on_delete_all_templates():
	if GlobalData.templates.size() == 0: return
	_show_confirmation_dialog(
		"Удалить ВСЕ шаблоны (%d шт.)?" % GlobalData.templates.size(),
		_do_delete_all_templates
	)

func _on_delete_all_assignments():
	if GlobalData.generated_assignments.size() == 0: return
	_show_confirmation_dialog(
		"Удалить ВСЕ задания (%d шт.)?" % GlobalData.generated_assignments.size(),
		_do_delete_all_assignments
	)
	
func _on_delete_selected_assignment():
	if selected_generated_assignment_index < 0 or selected_generated_assignment_index >= GlobalData.generated_assignments.size():
		_show_message("Выберите задание для удаления!")
		return
	
	var assignment = GlobalData.generated_assignments[selected_generated_assignment_index]
	var assignment_id = assignment.get("id", -1)
	
	if assignment_id <= 0:
		_show_message("Ошибка: у выбранного задания нет корректного ID")
		return
	
	_show_confirmation_dialog(
		"Удалить задание #%d?" % assignment_id,
		func(): _do_delete_assignment(assignment_id)
	)


func _do_delete_assignment(assignment_id: int):
	print(">>> DEBUG [MainUI]: Удаляю задание id=", assignment_id)
	BackendAPI.delete_assignment(assignment_id)
	await get_tree().create_timer(0.4).timeout
	BackendAPI.get_assignments()

func _show_confirmation_dialog(text: String, on_confirm: Callable):
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = text
	dialog.title = "Подтверждение"
	dialog.get_ok_button().text = "Да, удалить"
	dialog.confirmed.connect(func():
		on_confirm.call()
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _do_delete_template(template_id: int):
	BackendAPI.delete_template(template_id)
	await get_tree().create_timer(0.4).timeout
	BackendAPI.get_templates()

func _do_delete_all_templates():
	BackendAPI.delete_all_templates()
	await get_tree().create_timer(0.5).timeout
	BackendAPI.get_templates()

func _do_delete_all_assignments():
	BackendAPI.delete_all_assignments()
	await get_tree().create_timer(0.4).timeout
	BackendAPI.get_assignments()


# ==================== ДИАЛОГ СОЗДАНИЯ / РЕДАКТИРОВАНИЯ ====================

func _open_create_template_dialog(existing_template: Dictionary = {}):
	_dialog_param_controls.clear()
	var is_edit = existing_template.size() > 0
	
	var dialog = Window.new()
	dialog.title = "Редактирование шаблона" if is_edit else "Создание нового шаблона задания"
	dialog.size = Vector2(540, 720)
	dialog.min_size = Vector2(500, 600)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(main_vbox)

	# === ОБЩИЕ ПОЛЯ ===
	var common_title = Label.new()
	common_title.text = "Общие параметры"
	common_title.add_theme_font_size_override("font_size", 18)
	common_title.add_theme_color_override("font_color", Color.BLACK)   # ← ЧЁРНЫЙ
	main_vbox.add_child(common_title)

	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "Название шаблона"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_edit:
		name_edit.text = existing_template.get("name", "")
	main_vbox.add_child(name_edit)

	var type_option = OptionButton.new()
	type_option.add_item("Идентификация кости")
	type_option.add_item("Определение ориентиров")
	type_option.add_item("Сборка сустава")
	type_option.add_item("Сборка анатомической конструкции")
	type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_edit:
		var task_type = existing_template.get("task_type", "")
		for i in range(type_option.item_count):
			if type_option.get_item_text(i) == task_type:
				type_option.select(i)
				break
	main_vbox.add_child(type_option)

	var area_option = OptionButton.new()
	for i in range(GlobalData.anatomical_areas.size()):
		var area = GlobalData.anatomical_areas[i]
		area_option.add_item(area.name_ru)
		area_option.set_item_metadata(i, area.id)
	
	if is_edit:
		var area_id = existing_template.get("anatomical_area_id", 0)
		for i in range(area_option.item_count):
			if area_option.get_item_metadata(i) == area_id:
				area_option.select(i)
				break
	elif area_option.item_count > 0:
		area_option.select(0)
	area_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(area_option)

	var diff_hbox = HBoxContainer.new()
	main_vbox.add_child(diff_hbox)
	var diff_label = Label.new()
	diff_label.text = "Сложность: 2"
	diff_label.add_theme_color_override("font_color", Color.BLACK)   # ← ЧЁРНЫЙ
	diff_hbox.add_child(diff_label)
	
	var diff_slider = HSlider.new()
	diff_slider.min_value = 1
	diff_slider.max_value = 5
	diff_slider.value = existing_template.get("difficulty", 2) if is_edit else 2
	diff_slider.step = 1
	diff_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_hbox.add_child(diff_slider)
	diff_slider.value_changed.connect(func(v):
		diff_label.text = "Сложность: " + str(int(v))
	)

	var lang_option = OptionButton.new()
	lang_option.add_item("Русский")
	lang_option.add_item("Латынь")
	lang_option.add_item("Английский")
	if is_edit:
		var lang = existing_template.get("language", "Русский")
		for i in range(lang_option.item_count):
			if lang_option.get_item_text(i) == lang:
				lang_option.select(i)
				break
	else:
		lang_option.select(0)
	lang_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(lang_option)

	# === ДИНАМИЧЕСКИЕ ПАРАМЕТРЫ ===
	var params_title = Label.new()
	params_title.text = "Специфические параметры"
	params_title.add_theme_font_size_override("font_size", 16)
	params_title.add_theme_color_override("font_color", Color.BLACK)   # ← ЧЁРНЫЙ
	main_vbox.add_child(params_title)
	
	var params_vbox = VBoxContainer.new()
	params_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(params_vbox)

	type_option.item_selected.connect(func(_idx):
		var current_params = existing_template.get("parameters", {}) if is_edit else {}
		_rebuild_param_controls(params_vbox, type_option.get_item_text(type_option.selected), current_params)
	)

	var initial_type = type_option.get_item_text(type_option.selected)
	var initial_params = existing_template.get("parameters", {}) if is_edit else {}
	_rebuild_param_controls(params_vbox, initial_type, initial_params)

	# === КНОПКИ ===
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(btn_hbox)

	var cancel_btn = Button.new()
	cancel_btn.text = "Отмена"
	cancel_btn.pressed.connect(dialog.queue_free)
	btn_hbox.add_child(cancel_btn)

	var save_btn = Button.new()
	save_btn.text = "Сохранить изменения" if is_edit else "Сохранить шаблон"
	save_btn.pressed.connect(func():
		var template_name = name_edit.text.strip_edges()
		
		if template_name == "":
			_show_message("Введите название шаблона!")
			return
		
		# Проверка на одинаковые названия
		for t in GlobalData.templates:
			if t.get("name", "").strip_edges().to_lower() == template_name.to_lower():
				_show_message("Шаблон с таким названием уже существует!")
				return
		
		var params = _collect_params_from_controls()
		var area_id = area_option.get_item_metadata(area_option.selected)
		if area_id == null:
			area_id = 5
		area_id = int(area_id)
		
		var template_data = {
			"name": template_name,
			"task_type": type_option.get_item_text(type_option.selected),
			"anatomical_area_id": area_id,
			"difficulty": int(diff_slider.value),
			"language": lang_option.get_item_text(lang_option.selected),
			"parameters": params
		}
		
		_current_template_dialog = dialog
		
		if is_edit:
			var template_id = existing_template.get("id", -1)
			BackendAPI.update_template(template_id, template_data)
		else:
			BackendAPI.create_template(template_data)
	)
	btn_hbox.add_child(save_btn)

	get_tree().current_scene.add_child(dialog)
	dialog.popup_centered()


func _rebuild_param_controls(container: VBoxContainer, task_type: String, existing_params: Dictionary = {}):
	for child in container.get_children():
		child.queue_free()
	_dialog_param_controls.clear()

	match task_type:
		"Идентификация кости":
			var h = HBoxContainer.new()
			var l = Label.new()
			l.text = "Количество вариантов ответа:"
			l.add_theme_color_override("font_color", Color.BLACK)
			h.add_child(l)
			var spin = SpinBox.new()
			spin.min_value = 2
			spin.max_value = 10
			spin.value = existing_params.get("num_variants", 4)
			h.add_child(spin)
			container.add_child(h)
			_dialog_param_controls["num_variants"] = spin

			var h2 = HBoxContainer.new()
			var l2 = Label.new()
			l2.text = "Область для лишних костей:"
			l2.add_theme_color_override("font_color", Color.BLACK)
			h2.add_child(l2)
			var extra = OptionButton.new()
			for area in GlobalData.anatomical_areas:
				extra.add_item(area.name_ru, area.id)
			if existing_params.has("extra_bone_areas") and existing_params["extra_bone_areas"].size() > 0:
				var first = existing_params["extra_bone_areas"][0]
				for i in range(extra.item_count):
					if extra.get_item_id(i) == first:
						extra.select(i)
						break
			elif extra.item_count > 0:
				extra.select(0)
			h2.add_child(extra)
			container.add_child(h2)
			_dialog_param_controls["extra_bone_area"] = extra

		"Определение ориентиров":
			var h = HBoxContainer.new()
			var l = Label.new()
			l.text = "Количество ориентиров:"
			l.add_theme_color_override("font_color", Color.BLACK)
			h.add_child(l)
			var spin = SpinBox.new()
			spin.min_value = 1
			spin.max_value = 8
			spin.value = existing_params.get("num_landmarks", 3)
			h.add_child(spin)
			container.add_child(h)
			_dialog_param_controls["num_landmarks"] = spin

		"Сборка сустава":
			var check = CheckButton.new()
			check.text = "Использовать лишние кости"
			check.button_pressed = existing_params.get("use_extra_bones", false)
			container.add_child(check)
			_dialog_param_controls["use_extra_bones"] = check

			var h = HBoxContainer.new()
			var l = Label.new()
			l.text = "Количество лишних костей:"
			l.add_theme_color_override("font_color", Color.BLACK)
			h.add_child(l)
			var spin = SpinBox.new()
			spin.min_value = 0
			spin.max_value = 6
			spin.value = existing_params.get("extra_bone_count", 2)
			h.add_child(spin)
			container.add_child(h)
			_dialog_param_controls["extra_bone_count"] = spin

			var h2 = HBoxContainer.new()
			var l2 = Label.new()
			l2.text = "Область для лишних костей:"
			l2.add_theme_color_override("font_color", Color.BLACK)
			h2.add_child(l2)
			var extra = OptionButton.new()
			for area in GlobalData.anatomical_areas:
				extra.add_item(area.name_ru, area.id)
			if existing_params.has("extra_bone_areas") and existing_params["extra_bone_areas"].size() > 0:
				var first = existing_params["extra_bone_areas"][0]
				for i in range(extra.item_count):
					if extra.get_item_id(i) == first:
						extra.select(i)
						break
			elif extra.item_count > 0:
				extra.select(0)
			h2.add_child(extra)
			container.add_child(h2)
			_dialog_param_controls["extra_bone_area"] = extra

		"Сборка анатомической конструкции":
			var check = CheckButton.new()
			check.text = "Использовать лишние кости"
			check.button_pressed = existing_params.get("use_extra_bones", false)
			container.add_child(check)
			_dialog_param_controls["use_extra_bones"] = check

			var h = HBoxContainer.new()
			var l = Label.new()
			l.text = "Количество лишних костей:"
			l.add_theme_color_override("font_color", Color.BLACK)
			h.add_child(l)
			var spin = SpinBox.new()
			spin.min_value = 0
			spin.max_value = 8
			spin.value = existing_params.get("extra_bone_count", 3)
			h.add_child(spin)
			container.add_child(h)
			_dialog_param_controls["extra_bone_count"] = spin

			var h2 = HBoxContainer.new()
			var l2 = Label.new()
			l2.text = "Область для лишних костей:"
			l2.add_theme_color_override("font_color", Color.BLACK)
			h2.add_child(l2)
			var extra = OptionButton.new()
			for area in GlobalData.anatomical_areas:
				extra.add_item(area.name_ru, area.id)
			if existing_params.has("extra_bone_areas") and existing_params["extra_bone_areas"].size() > 0:
				var first = existing_params["extra_bone_areas"][0]
				for i in range(extra.item_count):
					if extra.get_item_id(i) == first:
						extra.select(i)
						break
			elif extra.item_count > 0:
				extra.select(0)
			h2.add_child(extra)
			container.add_child(h2)
			_dialog_param_controls["extra_bone_area"] = extra

			var check2 = CheckButton.new()
			check2.text = "Использовать дополнительные области"
			check2.button_pressed = existing_params.get("use_additional_areas", false)
			container.add_child(check2)
			_dialog_param_controls["use_additional_areas"] = check2


func _collect_params_from_controls() -> Dictionary:
	var params = {}
	for key in _dialog_param_controls.keys():
		var control = _dialog_param_controls[key]
		if control is SpinBox:
			params[key] = int(control.value)
		elif control is CheckButton:
			params[key] = control.button_pressed
		elif control is OptionButton:
			if control.item_count > 0:
				params[key] = control.get_item_id(control.selected)

	if params.has("extra_bone_area"):
		params["extra_bone_areas"] = [params["extra_bone_area"]]
		params.erase("extra_bone_area")

	return params


# ==================== ПЕРЕКЛЮЧЕНИЕ РОЛЕЙ ====================

func _switch_to_role(role: String):
	current_role = role
	teacher_panel.visible = (role == "teacher")
	student_panel.visible = (role == "student")
	
	if role == "teacher":
		teacher_btn.button_pressed = true
		student_btn.button_pressed = false
		_refresh_teacher_lists()
	else:
		teacher_btn.button_pressed = false
		student_btn.button_pressed = true
		_refresh_student_list()

func _on_teacher_btn_pressed():
	_switch_to_role("teacher")

func _on_student_btn_pressed():
	_switch_to_role("student")
