import json
import sys
from pathlib import Path

# Добавляем путь к app
sys.path.append(str(Path(__file__).parent.parent))

from app.database import SessionLocal, engine, Base
from app.models.anatomy import AnatomicalArea, Bone, Joint, Structure

# Создаём таблицы (если ещё не созданы)
Base.metadata.create_all(bind=engine)

db = SessionLocal()

json_path = Path(__file__).parent.parent / "data" / "anatomy_data.json"

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)

# === Анатомические области ===
for area in data["anatomical_areas"]:
    db_area = AnatomicalArea(
        id=area["id"],
        name_ru=area["name_ru"],
        name_lat=area.get("name_lat"),
        name_en=area.get("name_en")
    )
    db.merge(db_area)   # merge = insert или update

db.commit()
print(" Анатомические области загружены")

# === Кости ===
for bone in data["bones"]:
    db_bone = Bone(
        id=bone["id"],
        area_id=bone["area_id"],
        name_ru=bone["name_ru"],
        name_lat=bone.get("name_lat"),
        name_en=bone.get("name_en"),
        landmarks=bone.get("landmarks", [])
    )
    db.merge(db_bone)

db.commit()
print(" Кости загружены")

# === Суставы ===
for joint in data["joints"]:
    db_joint = Joint(
        id=joint["id"],
        area_id=joint.get("area_id"),
        name_ru=joint["name_ru"],
        name_lat=joint.get("name_lat"),
        name_en=joint.get("name_en"),
        bone_ids=joint.get("bone_ids", []),
        correct_connections=joint.get("correct_connections", []),
        description_ru=joint.get("description_ru")
    )
    db.merge(db_joint)

db.commit()
print(" Суставы загружены")

# === Конструкции ===
for struct in data["structures"]:
    db_struct = Structure(
        id=struct["id"],
        area_id=struct.get("area_id"),
        name_ru=struct["name_ru"],
        name_lat=struct.get("name_lat"),
        name_en=struct.get("name_en"),
        bone_ids=struct.get("bone_ids", []),
        correct_connections=struct.get("correct_connections", []),
        description_ru=struct.get("description_ru")
    )
    db.merge(db_struct)

db.commit()
print(" Анатомические конструкции загружены")

db.close()
print("\n Все данные успешно перенесены в PostgreSQL")