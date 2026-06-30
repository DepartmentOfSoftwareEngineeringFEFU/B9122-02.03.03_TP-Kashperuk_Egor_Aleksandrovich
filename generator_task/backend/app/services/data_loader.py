import json
from pathlib import Path
from typing import Dict, List, Any

DATA_PATH = Path(__file__).parent.parent.parent / "data" / "anatomy_data.json"

_anatomy_data: Dict[str, Any] = {}


def load_anatomy_data() -> Dict[str, Any]:
    global _anatomy_data
    if not _anatomy_data:
        with open(DATA_PATH, "r", encoding="utf-8") as f:
            _anatomy_data = json.load(f)
    return _anatomy_data


def get_areas() -> List[Dict]:
    return load_anatomy_data().get("anatomical_areas", [])


def get_bones_by_area(area_id: int) -> List[Dict]:
    bones = load_anatomy_data().get("bones", [])
    return [b for b in bones if b.get("area_id") == area_id]


def get_joints_by_area(area_id: int) -> List[Dict]:
    joints = load_anatomy_data().get("joints", [])
    return [j for j in joints if j.get("area_id") == area_id]


def get_structures_by_area(area_id: int) -> List[Dict]:
    structures = load_anatomy_data().get("structures", [])
    return [s for s in structures if s.get("area_id") == area_id]