extends Node

signal data_loaded
signal templates_changed()
signal assignments_changed()

# === ДАННЫЕ АНАТОМИИ (только из БД) ===
var anatomical_areas: Array = []
var bones: Array = []
var joints: Array = []
var structures: Array = []

var areas_by_id: Dictionary = {}
var bones_by_id: Dictionary = {}
var joints_by_id: Dictionary = {}
var structures_by_id: Dictionary = {}
var bones_by_area: Dictionary = {}   # area_id → Array of bones

var templates: Array = []
var generated_assignments: Array = []

var rng = RandomNumberGenerator.new()

var _anatomy_ready := false


func _ready() -> void:
	rng.randomize()

	# Подключаем сигналы
	BackendAPI.templates_received.connect(_on_templates_received)
	BackendAPI.template_created.connect(_on_template_created)
	BackendAPI.assignment_generated.connect(_on_assignment_generated)
	BackendAPI.assignments_received.connect(_on_assignments_received)
	BackendAPI.request_failed.connect(_on_request_failed)

	BackendAPI.areas_received.connect(_on_areas_received)
	BackendAPI.bones_received.connect(_on_bones_received)
	BackendAPI.joints_received.connect(_on_joints_received)
	BackendAPI.structures_received.connect(_on_structures_received)

	print(">>> DEBUG [GlobalData]: Загружаем анатомию с бэкенда...")
	_load_anatomy_from_backend()

	print(">>> DEBUG [GlobalData]: Загружаем шаблоны и задания...")
	BackendAPI.get_templates()
	BackendAPI.get_assignments()


# === ЗАГРУЗКА АНАТОМИИ ===
func _load_anatomy_from_backend():
	_anatomy_ready = false
	BackendAPI.get_areas()
	BackendAPI.get_bones()
	BackendAPI.get_joints()
	BackendAPI.get_structures()


func _build_lookup_tables():
	areas_by_id.clear()
	for area in anatomical_areas:
		areas_by_id[int(area.get("id", 0))] = area

	bones_by_id.clear()
	bones_by_area.clear()
	for bone in bones:
		var bid = int(bone.get("id", 0))
		bone["id"] = bid
		bones_by_id[bid] = bone

		var aid = int(bone.get("area_id", 0))
		if not bones_by_area.has(aid):
			bones_by_area[aid] = []
		bones_by_area[aid].append(bone)

	joints_by_id.clear()
	for j in joints:
		joints_by_id[int(j.get("id", 0))] = j

	structures_by_id.clear()
	for s in structures:
		structures_by_id[int(s.get("id", 0))] = s

	print(">>> DEBUG [GlobalData]: Lookup таблицы построены. Областей: %d, Костей: %d" % [
		areas_by_id.size(), bones_by_id.size()
	])


func _check_anatomy_ready():
	if anatomical_areas.size() > 0 and bones.size() > 0 and not _anatomy_ready:
		_build_lookup_tables()
		_anatomy_ready = true
		print(">>> DEBUG [GlobalData]: Анатомия загружена и готова к работе")
		emit_signal("data_loaded")


# === Обработчики данных анатомии ===
func _on_areas_received(areas: Array):
	print(">>> DEBUG [GlobalData]: Получено областей:", areas.size())
	anatomical_areas = areas
	_check_anatomy_ready()

func _on_bones_received(bones_data: Array):
	print(">>> DEBUG [GlobalData]: Получено костей:", bones_data.size())
	bones = bones_data
	_check_anatomy_ready()

func _on_joints_received(joints_data: Array):
	joints = joints_data
	_check_anatomy_ready()

func _on_structures_received(structures_data: Array):
	structures = structures_data
	_check_anatomy_ready()


# === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
func get_area_name(area_id: int, lang: String = "ru") -> String:
	if not areas_by_id.has(area_id):
		return "Неизвестная область"
	var area = areas_by_id[area_id]
	match lang.to_lower():
		"lat", "латынь", "latin": return area.get("name_lat", area.get("name_ru", ""))
		"en", "english", "английский": return area.get("name_en", area.get("name_ru", ""))
		_: return area.get("name_ru", "")

func get_bone_name(bone_id: int, lang: String = "ru") -> String:
	if not bones_by_id.has(bone_id):
		return "Неизвестная кость #" + str(bone_id)
	var bone = bones_by_id[bone_id]
	match lang.to_lower():
		"lat", "латынь": return bone.get("name_lat", bone.get("name_ru", ""))
		"en", "english", "английский": return bone.get("name_en", bone.get("name_ru", ""))
		_: return bone.get("name_ru", "")


func get_bones_in_areas(area_ids: Array) -> Array:
	var result = []
	for aid in area_ids:
		if bones_by_area.has(aid):
			result.append_array(bones_by_area[aid])
	return result

func get_random_bone_from_area(area_id: int, exclude_ids: Array = []) -> Dictionary:
	if not bones_by_area.has(area_id):
		return {}
	var candidates = bones_by_area[area_id].filter(func(b): return not exclude_ids.has(b.get("id", 0)))
	if candidates.is_empty():
		return {}
	return candidates[rng.randi() % candidates.size()]

func get_random_joints_for_area(area_id: int) -> Array:
	return joints.filter(func(j): return int(j.get("area_id", 0)) == area_id)

func get_random_structure_for_area(area_id: int) -> Dictionary:
	var candidates = structures.filter(func(s): return int(s.get("area_id", 0)) == area_id)
	if candidates.is_empty():
		return {}
	return candidates[rng.randi() % candidates.size()]


# === ГЕНЕРАТОР ЗАДАНИЙ (оставлен без изменений) ===
func generate_assignment_from_template(template: Dictionary) -> Dictionary:
	var assignment = {
		"id": rng.randi(),
		"template_id": template.get("id", -1),
		"task_type": template.get("task_type", ""),
		"anatomical_area_id": template.get("anatomical_area_id", 0),
		"anatomical_area_name": get_area_name(template.get("anatomical_area_id", 0), template.get("language", "ru")),
		"difficulty": template.get("difficulty", 1),
		"language": template.get("language", "Русский"),
		"created_at": Time.get_datetime_string_from_system(false, true),
		"data": {}
	}
	match template.get("task_type", ""):
		"Идентификация кости":
			assignment.data = _generate_bone_identification(template)
		"Определение ориентиров":
			assignment.data = _generate_landmark_identification(template)
		"Сборка сустава":
			assignment.data = _generate_joint_assembly(template)
		"Сборка анатомической конструкции":
			assignment.data = _generate_structure_assembly(template)
		_:
			assignment.data = {"error": "unknown type"}
	return assignment


func _generate_bone_identification(template: Dictionary) -> Dictionary:
	var main_area = template.anatomical_area_id
	var params = template.get("params", {})
	var num_variants = params.get("num_variants", 4)
	var extra_areas = params.get("extra_bone_areas", [main_area])
	
	var target_bone = get_random_bone_from_area(main_area)
	if target_bone.is_empty():
		target_bone = {"id": -1, "name_ru": "Ошибка: нет костей"}
	
	var target_id = target_bone.id
	
	var pool_areas = extra_areas.duplicate()
	if not pool_areas.has(main_area):
		pool_areas.append(main_area)
	
	var all_candidates = get_bones_in_areas(pool_areas)
	var distractor_pool = all_candidates.filter(func(b): return b.id != target_id)
	
	var option_ids = [target_id]
	var used_ids = [target_id]
	for i in range(num_variants - 1):
		if distractor_pool.is_empty():
			break
		var idx = rng.randi() % distractor_pool.size()
		var d = distractor_pool[idx]
		option_ids.append(d.id)
		used_ids.append(d.id)
		distractor_pool.remove_at(idx)
	
	option_ids.shuffle()
	
	var option_names = {}
	for oid in option_ids:
		option_names[oid] = get_bone_name(oid, template.language)
	
	return {
		"target_bone_id": target_id,
		"target_bone_name": get_bone_name(target_id, template.language),
		"option_bone_ids": option_ids,
		"option_names": option_names,
		"correct_bone_id": target_id,
		"question_text": "Идентифицируйте кость, принадлежащую области «%s»" % get_area_name(main_area, template.language)
	}


func _generate_landmark_identification(template: Dictionary) -> Dictionary:
	var main_area = template.anatomical_area_id
	var params = template.get("params", {})
	var num_landmarks = params.get("num_landmarks", 2)
	
	var candidates = bones_by_area.get(main_area, []).filter(func(b): return b.get("landmarks", []).size() > 0)
	if candidates.is_empty():
		candidates = bones.filter(func(b): return b.get("landmarks", []).size() > 0)
	if candidates.is_empty():
		return {"error": "Нет костей с ориентирами в данных"}
	
	var target_bone = candidates[rng.randi() % candidates.size()]
	var all_landmarks = target_bone.get("landmarks", [])
	
	var target_landmark_ids = []
	var target_names = {}
	var shuffled_lms = all_landmarks.duplicate()
	shuffled_lms.shuffle()
	for i in range(min(num_landmarks, shuffled_lms.size())):
		var lm = shuffled_lms[i]
		target_landmark_ids.append(lm.id)
		target_names[lm.id] = lm.get("name_" + _lang_to_suffix(template.language), lm.name_ru)
	
	return {
		"bone_id": target_bone.id,
		"bone_name": get_bone_name(target_bone.id, template.language),
		"target_landmark_ids": target_landmark_ids,
		"target_landmark_names": target_names,
		"all_landmarks_on_bone": all_landmarks,
		"question_text": "На кости «%s» укажите заданные анатомические ориентиры" % get_bone_name(target_bone.id, template.language)
	}


func _lang_to_suffix(lang: String) -> String:
	match lang.to_lower():
		"lat", "латынь": return "lat"
		"en", "english", "английский": return "en"
		_: return "ru"


func _generate_joint_assembly(template: Dictionary) -> Dictionary:
	var main_area = template.anatomical_area_id
	var params = template.get("params", {})
	var use_extra = params.get("use_extra_bones", false)
	var extra_count = params.get("extra_bone_count", 2)
	var extra_areas = params.get("extra_bone_areas", [main_area])
	
	var available_joints = get_random_joints_for_area(main_area)
	if available_joints.is_empty():
		available_joints = joints
	if available_joints.is_empty():
		return {"error": "Нет суставов в данных"}
	
	var selected_joint = available_joints[rng.randi() % available_joints.size()]
	var target_bone_ids = selected_joint.get("bone_ids", []).duplicate()
	
	var all_bone_ids = target_bone_ids.duplicate()
	var extra_bone_ids = []
	
	if use_extra:
		var extra_pool = get_bones_in_areas(extra_areas)
		extra_pool = extra_pool.filter(func(b): return not target_bone_ids.has(b.id))
		for i in range(extra_count):
			if extra_pool.is_empty():
				break
			var eb = extra_pool[rng.randi() % extra_pool.size()]
			extra_bone_ids.append(eb.id)
			all_bone_ids.append(eb.id)
			extra_pool = extra_pool.filter(func(b): return b.id != eb.id)
	
	all_bone_ids.shuffle()
	
	var bone_names = {}
	for bid in all_bone_ids:
		bone_names[bid] = get_bone_name(bid, template.language)
	
	return {
		"joint_id": selected_joint.id,
		"joint_name": selected_joint.get("name_" + _lang_to_suffix(template.language), selected_joint.name_ru),
		"target_bone_ids": target_bone_ids,
		"extra_bone_ids": extra_bone_ids,
		"all_bone_ids": all_bone_ids,
		"bone_names": bone_names,
		"correct_connections": selected_joint.get("correct_connections", []),
		"question_text": "Соберите %s из предоставленных костей" % selected_joint.get("name_ru", "сустав")
	}


func _generate_structure_assembly(template: Dictionary) -> Dictionary:
	var main_area = template.anatomical_area_id
	var params = template.get("params", {})
	var use_extra = params.get("use_extra_bones", false)
	var extra_count = params.get("extra_bone_count", 3)
	var extra_areas = params.get("extra_bone_areas", [main_area])
	var additional_areas = params.get("additional_areas", [])
	
	var selected_structure = get_random_structure_for_area(main_area)
	if selected_structure.is_empty():
		if structures.is_empty():
			return {"error": "Нет структур в данных"}
		selected_structure = structures[0]
	
	var target_bone_ids = selected_structure.get("bone_ids", []).duplicate()
	
	for add_a in additional_areas:
		if bones_by_area.has(add_a):
			var extra_from_add = bones_by_area[add_a].slice(0, 2)
			for eb in extra_from_add:
				if not target_bone_ids.has(eb.id):
					target_bone_ids.append(eb.id)
	
	var all_bone_ids = target_bone_ids.duplicate()
	var extra_bone_ids = []
	
	if use_extra:
		var extra_pool = get_bones_in_areas(extra_areas)
		extra_pool = extra_pool.filter(func(b): return not target_bone_ids.has(b.id))
		for i in range(extra_count):
			if extra_pool.is_empty():
				break
			var eb = extra_pool[rng.randi() % extra_pool.size()]
			extra_bone_ids.append(eb.id)
			all_bone_ids.append(eb.id)
			extra_pool = extra_pool.filter(func(b): return b.id != eb.id)
	
	all_bone_ids.shuffle()
	
	var bone_names = {}
	for bid in all_bone_ids:
		bone_names[bid] = get_bone_name(bid, template.language)
	
	return {
		"structure_id": selected_structure.id,
		"structure_name": selected_structure.get("name_" + _lang_to_suffix(template.language), selected_structure.name_ru),
		"target_bone_ids": target_bone_ids,
		"extra_bone_ids": extra_bone_ids,
		"all_bone_ids": all_bone_ids,
		"bone_names": bone_names,
		"correct_connections": selected_structure.get("correct_connections", []),
		"question_text": "Соберите анатомическую конструкцию «%s»" % selected_structure.get("name_ru", "структура")
	}


# === РАБОТА С ШАБЛОНАМИ И ЗАДАНИЯМИ ===
func create_new_template(template_name: String, task_type: String, area_id: int, difficulty: int, language: String, params: Dictionary) -> void:
	var template_data = {
		"name": template_name,
		"task_type": task_type,
		"anatomical_area_id": area_id,
		"difficulty": difficulty,
		"language": language,
		"parameters": params
	}
	BackendAPI.create_template(template_data)


func add_generated_assignment(assignment: Dictionary):
	generated_assignments.append(assignment)
	emit_signal("assignments_changed")


func clear_all_data():
	templates.clear()
	generated_assignments.clear()
	emit_signal("templates_changed")
	emit_signal("assignments_changed")


# === ОБРАБОТЧИКИ СИГНАЛОВ ===
func _on_templates_received(templates_array: Array) -> void:
	templates = templates_array
	templates_changed.emit()

func _on_template_created(template: Dictionary) -> void:
	var template_id = template.get("id", -1)
	if template_id <= 0: return
	var found = -1
	for i in range(templates.size()):
		if templates[i].get("id", -1) == template_id:
			found = i
			break
	if found != -1:
		templates[found] = template
	else:
		templates.append(template)
	templates_changed.emit()

func _on_assignment_generated(assignment: Dictionary) -> void:
	generated_assignments.append(assignment)
	assignments_changed.emit()

func _on_assignments_received(assignments: Array) -> void:
	generated_assignments = assignments
	assignments_changed.emit()

func _on_request_failed(error_message: String) -> void:
	print(">>> DEBUG [GlobalData]: Ошибка запроса к backend:", error_message)
