from typing import Dict, Any, List
from app.services.data_loader import (
    get_bones_by_area,
    get_joints_by_area,
    get_structures_by_area
)


def validate_template_parameters(
    task_type: str,
    anatomical_area_id: int,
    parameters: Dict[str, Any]
) -> None:
    """
    Валидирует параметры шаблона в зависимости от типа задания.
    Если параметры некорректны — выбрасывает ValueError с понятным сообщением.
    """

    if task_type == "Идентификация кости":
        _validate_bone_identification(anatomical_area_id, parameters)

    elif task_type == "Определение ориентиров":
        _validate_landmark_determination(anatomical_area_id, parameters)

    elif task_type == "Сборка сустава":
        _validate_joint_assembly(anatomical_area_id, parameters)

    elif task_type == "Сборка анатомической конструкции":
        _validate_structure_assembly(anatomical_area_id, parameters)


# ============================================================
# Валидация для "Идентификация кости"
# ============================================================
def _validate_bone_identification(area_id: int, params: Dict[str, Any]) -> None:
    main_bones = get_bones_by_area(area_id)
    if not main_bones:
        raise ValueError(f"В области {area_id} нет костей")

    extra_area_ids: List[int] = params.get("extra_bone_areas", [])
    extra_bones_count = 0
    for extra_id in extra_area_ids:
        extra_bones_count += len(get_bones_by_area(extra_id))

    max_variants = extra_bones_count + 1  # +1 за правильный вариант

    num_variants = params.get("num_variants", 4)

    if num_variants > max_variants:
        raise ValueError(
            f"Количество вариантов ({num_variants}) не может быть больше "
            f"доступного количества ({max_variants}) "
            f"(1 правильный + {extra_bones_count} лишних костей)"
        )


# ============================================================
# Валидация для "Определение ориентиров"
# ============================================================
def _validate_landmark_determination(area_id: int, params: Dict[str, Any]) -> None:
    bones = get_bones_by_area(area_id)
    bones_with_landmarks = [b for b in bones if b.get("landmarks")]

    if not bones_with_landmarks:
        raise ValueError(f"В области {area_id} нет костей с ориентирами")

    max_landmarks = max(len(b["landmarks"]) for b in bones_with_landmarks)
    num_landmarks = params.get("num_landmarks", 3)

    if num_landmarks > max_landmarks:
        raise ValueError(
            f"Количество ориентиров ({num_landmarks}) не может быть больше "
            f"максимального доступного на одной кости в этой области ({max_landmarks})"
        )


# ============================================================
# Валидация для "Сборка сустава"
# ============================================================
def _validate_joint_assembly(area_id: int, params: Dict[str, Any]) -> None:
    if not params.get("use_extra_bones", False):
        return

    extra_area_ids: List[int] = params.get("extra_bone_areas", [])
    extra_count = params.get("extra_bone_count", 2)

    total_extra_bones = 0
    for extra_id in extra_area_ids:
        total_extra_bones += len(get_bones_by_area(extra_id))

    if extra_count > total_extra_bones:
        raise ValueError(
            f"Количество лишних костей ({extra_count}) не может быть больше "
            f"доступного количества в указанных областях ({total_extra_bones})"
        )


# ============================================================
# Валидация для "Сборка анатомической конструкции"
# ============================================================
def _validate_structure_assembly(area_id: int, params: Dict[str, Any]) -> None:
    if not params.get("use_extra_bones", False):
        return

    extra_area_ids: List[int] = params.get("extra_bone_areas", [])
    extra_count = params.get("extra_bone_count", 3)

    total_extra_bones = 0
    for extra_id in extra_area_ids:
        total_extra_bones += len(get_bones_by_area(extra_id))

    if extra_count > total_extra_bones:
        raise ValueError(
            f"Количество лишних костей ({extra_count}) не может быть больше "
            f"доступного количества в указанных областях ({total_extra_bones})"
        )