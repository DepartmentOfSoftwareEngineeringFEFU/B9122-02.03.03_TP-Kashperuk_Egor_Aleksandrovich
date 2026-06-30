import random
from typing import Dict, Any, List
from app.models.template import Template
from app.services.data_loader import (
    get_bones_by_area,
    get_joints_by_area,
    get_structures_by_area
)


def generate_assignment_from_template(template: Template) -> Dict[str, Any]:
    task_type = template.task_type
    area_id = template.anatomical_area_id
    params = template.parameters or {}

    if task_type == "Идентификация кости":
        return _generate_bone_identification(area_id, params)
    elif task_type == "Определение ориентиров":
        return _generate_landmark_determination(area_id, params)
    elif task_type == "Сборка сустава":
        return _generate_joint_assembly(area_id, params)
    elif task_type == "Сборка анатомической конструкции":
        return _generate_structure_assembly(area_id, params)
    else:
        return {"error": f"Unknown task type: {task_type}"}


# ============================================================
# 1. ИДЕНТИФИКАЦИЯ КОСТИ
# ============================================================
def _generate_bone_identification(area_id: int, params: dict) -> Dict[str, Any]:
    main_bones = get_bones_by_area(area_id)
    if not main_bones:
        return {"error": f"No bones found for area_id={area_id}"}

    # === Получаем лишние кости из указанных областей ===
    extra_area_ids: List[int] = params.get("extra_bone_areas", [])
    extra_bones: List[Dict] = []
    for extra_id in extra_area_ids:
        extra_bones.extend(get_bones_by_area(extra_id))

    # === Ограничение количества вариантов ===
    num_variants = params.get("num_variants", 4)
    max_extra = len(extra_bones)
    num_variants = max(2, min(num_variants, max_extra + 1))  # минимум 2, максимум = все лишние + 1 правильный

    target_bone = random.choice(main_bones)
    all_candidates = [b for b in main_bones + extra_bones if b["id"] != target_bone["id"]]

    distractors = random.sample(all_candidates, min(num_variants - 1, len(all_candidates)))

    options = [target_bone] + distractors
    random.shuffle(options)

    return {
        "task_type": "Идентификация кости",
        "target_bone_id": target_bone["id"],
        "target_bone_name": target_bone.get("name_ru") or target_bone.get("name"),
        "options": [
            {"id": b["id"], "name": b.get("name_ru") or b.get("name")}
            for b in options
        ],
        "correct_bone_id": target_bone["id"],
        "anatomical_area_id": area_id,
        "extra_areas_used": extra_area_ids,
        "num_variants": len(options)
    }


# ============================================================
# 2. ОПРЕДЕЛЕНИЕ ОРИЕНТИРОВ
# ============================================================
def _generate_landmark_determination(area_id: int, params: dict) -> Dict[str, Any]:
    bones = get_bones_by_area(area_id)
    if not bones:
        return {"error": f"No bones found for area_id={area_id}"}

    bones_with_landmarks = [b for b in bones if b.get("landmarks")]
    if not bones_with_landmarks:
        return {"error": "No bones with landmarks in this area"}

    target_bone = random.choice(bones_with_landmarks)
    landmarks = target_bone.get("landmarks", [])

    # === Ограничение количества ориентиров ===
    num_landmarks = params.get("num_landmarks", 3)
    num_landmarks = max(1, min(num_landmarks, len(landmarks)))

    selected_landmarks = random.sample(landmarks, num_landmarks)

    return {
        "task_type": "Определение ориентиров",
        "target_bone_id": target_bone["id"],
        "target_bone_name": target_bone.get("name_ru") or target_bone.get("name"),
        "landmarks": [
            {
                "id": lm["id"],
                "name_ru": lm.get("name_ru"),
                "name_lat": lm.get("name_lat")
            }
            for lm in selected_landmarks
        ],
        "correct_landmark_ids": [lm["id"] for lm in selected_landmarks],
        "anatomical_area_id": area_id,
        "num_landmarks": num_landmarks
    }


# ============================================================
# 3. СБОРКА СУСТАВА
# ============================================================
def _generate_joint_assembly(area_id: int, params: dict) -> Dict[str, Any]:
    joints = get_joints_by_area(area_id)
    if not joints:
        return {"error": f"No joints found for area_id={area_id}"}

    joint = random.choice(joints)

    use_extra = params.get("use_extra_bones", False)
    extra_area_ids: List[int] = params.get("extra_bone_areas", [])
    extra_count = params.get("extra_bone_count", 2)

    all_bone_ids = set(joint.get("bone_ids", []))
    extra_bones: List[Dict] = []

    if use_extra and extra_area_ids:
        for extra_id in extra_area_ids:
            extra_bones.extend(get_bones_by_area(extra_id))

    # === Ограничение количества лишних костей ===
    available_extra = [b for b in extra_bones if b["id"] not in all_bone_ids]
    extra_count = min(extra_count, len(available_extra))

    if extra_count > 0:
        selected_extra = random.sample(available_extra, extra_count)
        extra_bone_ids = [b["id"] for b in selected_extra]
        all_bone_ids.update(extra_bone_ids)
    else:
        extra_bone_ids = []

    return {
        "task_type": "Сборка сустава",
        "joint_id": joint["id"],
        "joint_name": joint.get("name_ru") or joint.get("name"),
        "target_bone_ids": list(all_bone_ids),
        "correct_connections": joint.get("correct_connections", []),
        "anatomical_area_id": area_id,
        "use_extra_bones": use_extra,
        "extra_bone_ids": extra_bone_ids
    }


# ============================================================
# 4. СБОРКА АНАТОМИЧЕСКОЙ КОНСТРУКЦИИ
# ============================================================
def _generate_structure_assembly(area_id: int, params: dict) -> Dict[str, Any]:
    structures = get_structures_by_area(area_id)
    if not structures:
        return {"error": f"No structures found for area_id={area_id}"}

    structure = random.choice(structures)

    use_extra_bones: bool = params.get("use_extra_bones", False)
    extra_bone_areas: List[int] = params.get("extra_bone_areas", [])
    extra_count = params.get("extra_bone_count", 3)

    use_additional_areas: bool = params.get("use_additional_areas", False)
    additional_areas: List[int] = params.get("additional_areas", [])

    target_bone_ids: set = set(structure.get("bone_ids", []))

    # Добавляем кости из дополнительных областей
    if use_additional_areas and additional_areas:
        for add_id in additional_areas:
            bones = get_bones_by_area(add_id)
            target_bone_ids.update([b["id"] for b in bones])

    extra_bone_ids = []

    if use_extra_bones and extra_bone_areas:
        extra_bones: List[Dict] = []
        for extra_id in extra_bone_areas:
            extra_bones.extend(get_bones_by_area(extra_id))

        available_extra = [b for b in extra_bones if b["id"] not in target_bone_ids]
        extra_count = min(extra_count, len(available_extra))

        if extra_count > 0:
            selected_extra = random.sample(available_extra, extra_count)
            extra_bone_ids = [b["id"] for b in selected_extra]
            target_bone_ids.update(extra_bone_ids)

    return {
        "task_type": "Сборка анатомической конструкции",
        "structure_id": structure["id"],
        "structure_name": structure.get("name_ru") or structure.get("name"),
        "target_bone_ids": sorted(list(target_bone_ids)),
        "anatomical_area_id": area_id,
        "use_extra_bones": use_extra_bones,
        "extra_bone_ids": extra_bone_ids,
        "use_additional_areas": use_additional_areas,
        "additional_areas_used": additional_areas if use_additional_areas else []
    }