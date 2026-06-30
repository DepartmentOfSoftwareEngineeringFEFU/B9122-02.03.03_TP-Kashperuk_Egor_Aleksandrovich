extends Node

const BASE_URL := "http://127.0.0.1:8000"

# === СИГНАЛЫ ===
signal templates_received(templates: Array)
signal template_created(template: Dictionary)
signal assignment_generated(assignment: Dictionary)
signal assignments_received(assignments: Array)
signal request_failed(error_message: String)

signal areas_received(areas: Array)
signal bones_received(bones: Array)
signal joints_received(joints: Array)
signal structures_received(structures: Array)

# === НОВОЕ: отслеживание типа последнего запроса ===
var _last_request_type: String = ""   # "templates", "assignments", "anatomy"

# === ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ ===
func _create_http_request() -> HTTPRequest:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(
		func(result, response_code, headers, body):
			_on_request_completed(http, result, response_code, headers, body)
	)
	return http


# === ШАБЛОНЫ И ЗАДАНИЯ ===
func get_templates() -> void:
	_last_request_type = "templates"
	var http := _create_http_request()
	http.request(BASE_URL + "/templates/")

func create_template(data: Dictionary) -> void:
	var http := _create_http_request()
	var json_string = JSON.stringify(data)
	http.request(BASE_URL + "/templates/", ["Content-Type: application/json"], HTTPClient.METHOD_POST, json_string)

func generate_assignment(template_id: int) -> void:
	var http := _create_http_request()
	var url = BASE_URL + "/templates/" + str(template_id) + "/generate"
	http.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, "")

func get_assignments() -> void:
	_last_request_type = "assignments"
	var http := _create_http_request()
	http.request(BASE_URL + "/assignments/")

func delete_template(template_id: int) -> void:
	_last_request_type = "templates"
	var http := _create_http_request()
	http.request(BASE_URL + "/templates/" + str(template_id), [], HTTPClient.METHOD_DELETE, "")

func delete_all_templates() -> void:
	_last_request_type = "templates"
	var http := _create_http_request()
	http.request(BASE_URL + "/templates/", [], HTTPClient.METHOD_DELETE, "")

func delete_assignment(assignment_id: int) -> void:
	_last_request_type = "assignments"
	var http := _create_http_request()
	http.request(BASE_URL + "/assignments/" + str(assignment_id), [], HTTPClient.METHOD_DELETE, "")

func delete_all_assignments() -> void:
	_last_request_type = "assignments"
	var http := _create_http_request()
	http.request(BASE_URL + "/assignments/", [], HTTPClient.METHOD_DELETE, "")

func update_template(template_id: int, data: Dictionary) -> void:
	var http := _create_http_request()
	var json_string = JSON.stringify(data)
	http.request(BASE_URL + "/templates/" + str(template_id), ["Content-Type: application/json"], HTTPClient.METHOD_PUT, json_string)


# === АНАТОМИЧЕСКИЕ ДАННЫЕ ===
func get_areas() -> void:
	_last_request_type = "anatomy"
	var http := _create_http_request()
	http.request(BASE_URL + "/anatomy/areas")

func get_bones(area_id: int = 0) -> void:
	_last_request_type = "anatomy"
	var http := _create_http_request()
	var url = BASE_URL + "/anatomy/bones"
	if area_id > 0:
		url += "?area_id=" + str(area_id)
	http.request(url)

func get_joints(area_id: int = 0) -> void:
	_last_request_type = "anatomy"
	var http := _create_http_request()
	var url = BASE_URL + "/anatomy/joints"
	if area_id > 0:
		url += "?area_id=" + str(area_id)
	http.request(url)

func get_structures(area_id: int = 0) -> void:
	_last_request_type = "anatomy"
	var http := _create_http_request()
	var url = BASE_URL + "/anatomy/structures"
	if area_id > 0:
		url += "?area_id=" + str(area_id)
	http.request(url)


# === ОБРАБОТКА ОТВЕТОВ (главное исправление) ===
func _on_request_completed(http: HTTPRequest, result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	http.queue_free()

	if response_code != 200:
		var error = body.get_string_from_utf8()
		print("Backend error: ", error)
		request_failed.emit(error)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		print("Failed to parse JSON")
		return

	var data = json.data

	if data is Array:
		if data.size() > 0:
			var first = data[0]

			if first.has("template_id"):
				print(">>> DEBUG [BackendAPI]: Получен список ЗАДАНИЙ (", data.size(), " шт.)")
				assignments_received.emit(data)

			elif first.has("name_ru") and first.has("id"):
				if first.has("landmarks"):
					print(">>> DEBUG [BackendAPI]: Получен список КОСТЕЙ")
					bones_received.emit(data)
				elif first.has("bone_ids") and first.has("correct_connections"):
					print(">>> DEBUG [BackendAPI]: Получен список СУСТАВОВ/СТРУКТУР")
					joints_received.emit(data)
				else:
					print(">>> DEBUG [BackendAPI]: Получен список ОБЛАСТЕЙ")
					areas_received.emit(data)
			else:
				print(">>> DEBUG [BackendAPI]: Получен список ШАБЛОНОВ (", data.size(), " шт.)")
				templates_received.emit(data)
		else:
			# === ПУСТОЙ МАССИВ — теперь определяем по _last_request_type ===
			print(">>> DEBUG [BackendAPI]: Получен ПУСТОЙ список от типа: ", _last_request_type)
			if _last_request_type == "templates":
				templates_received.emit(data)
			elif _last_request_type == "assignments":
				assignments_received.emit(data)
			else:
				# на всякий случай
				templates_received.emit(data)
				assignments_received.emit(data)

	elif data is Dictionary:
		if data.has("id") and data.has("template_id"):
			print(">>> DEBUG [BackendAPI]: Получено задание")
			assignment_generated.emit(data)
		elif data.has("id") and data.has("name"):
			print(">>> DEBUG [BackendAPI]: Создан/обновлён шаблон")
			template_created.emit(data)
