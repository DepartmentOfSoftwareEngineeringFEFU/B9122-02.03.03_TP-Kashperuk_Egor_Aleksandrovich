from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app.models.anatomy import AnatomicalArea, Bone, Joint, Structure

router = APIRouter(prefix="/anatomy", tags=["Anatomy Data"])

@router.get("/areas", response_model=List[dict])
def get_areas(db: Session = Depends(get_db)):
    areas = db.query(AnatomicalArea).all()
    return [
        {
            "id": a.id,
            "name_ru": a.name_ru,
            "name_lat": a.name_lat,
            "name_en": a.name_en
        }
        for a in areas
    ]

@router.get("/bones", response_model=List[dict])
def get_bones(area_id: int = None, db: Session = Depends(get_db)):
    query = db.query(Bone)
    if area_id:
        query = query.filter(Bone.area_id == area_id)
    bones = query.all()
    return [
        {
            "id": b.id,
            "area_id": b.area_id,
            "name_ru": b.name_ru,
            "name_lat": b.name_lat,
            "name_en": b.name_en,
            "landmarks": b.landmarks or []
        }
        for b in bones
    ]

@router.get("/joints", response_model=List[dict])
def get_joints(area_id: int = None, db: Session = Depends(get_db)):
    query = db.query(Joint)
    if area_id:
        query = query.filter(Joint.area_id == area_id)
    joints = query.all()
    return [
        {
            "id": j.id,
            "area_id": j.area_id,
            "name_ru": j.name_ru,
            "name_lat": j.name_lat,
            "name_en": j.name_en,
            "bone_ids": j.bone_ids or [],
            "correct_connections": j.correct_connections or []
        }
        for j in joints
    ]

@router.get("/structures", response_model=List[dict])
def get_structures(area_id: int = None, db: Session = Depends(get_db)):
    query = db.query(Structure)
    if area_id:
        query = query.filter(Structure.area_id == area_id)
    structures = query.all()
    return [
        {
            "id": s.id,
            "area_id": s.area_id,
            "name_ru": s.name_ru,
            "name_lat": s.name_lat,
            "name_en": s.name_en,
            "bone_ids": s.bone_ids or [],
            "correct_connections": s.correct_connections or []
        }
        for s in structures
    ]