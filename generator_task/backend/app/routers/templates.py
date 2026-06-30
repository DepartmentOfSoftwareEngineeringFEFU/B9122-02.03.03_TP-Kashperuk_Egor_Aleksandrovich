from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import Optional
from app.database import get_db
from app.models.template import Template
from app.schemas.template import TemplateCreate, TemplateResponse
from app.services.generator import generate_assignment_from_template
from app.schemas.assignment import AssignmentResponse
from app.models.assignment import Assignment
from app.services.validator import validate_template_parameters

router = APIRouter(
    prefix="/templates",
    tags=["Templates"]
)


@router.post("/", response_model=TemplateResponse)
def create_template(template: TemplateCreate, db: Session = Depends(get_db)):
    # === ВАЛИДАЦИЯ ПАРАМЕТРОВ ===
    try:
        validate_template_parameters(
            task_type=template.task_type,
            anatomical_area_id=template.anatomical_area_id,
            parameters=template.parameters or {}
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    db_template = Template(
        name=template.name,
        task_type=template.task_type,
        anatomical_area_id=template.anatomical_area_id,
        difficulty=template.difficulty,
        language=template.language,
        parameters=template.parameters
    )
    db.add(db_template)
    db.commit()
    db.refresh(db_template)
    return db_template


@router.get("/", response_model=list[TemplateResponse])
def get_templates(
    skip: int = 0,
    limit: int = 100,
    task_type: Optional[str] = Query(None, description="Фильтр по типу задания"),
    anatomical_area_id: Optional[int] = Query(None, description="Фильтр по ID области"),
    difficulty: Optional[int] = Query(None, description="Фильтр по уровню сложности"),
    db: Session = Depends(get_db)
):
    query = db.query(Template)

    # === ГЛАВНОЕ ИЗМЕНЕНИЕ: показываем только неудалённые шаблоны ===
    query = query.filter(Template.is_deleted == False)

    if task_type:
        query = query.filter(Template.task_type == task_type)
    if anatomical_area_id:
        query = query.filter(Template.anatomical_area_id == anatomical_area_id)
    if difficulty:
        query = query.filter(Template.difficulty == difficulty)

    return query.offset(skip).limit(limit).all()

"""
@router.get("/", response_model=list[TemplateResponse])
def get_all_templates(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    templates = db.query(Template).offset(skip).limit(limit).all()
    return templates
"""

@router.get("/{template_id}", response_model=TemplateResponse)
def get_template(template_id: int, db: Session = Depends(get_db)):
    template = db.query(Template).filter(Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")
    return template


@router.delete("/{template_id}")
def delete_template(template_id: int, db: Session = Depends(get_db)):
    template = db.query(Template).filter(
        Template.id == template_id,
        Template.is_deleted == False
    ).first()

    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    template.is_deleted = True
    db.commit()
    return {"message": "Template soft-deleted successfully"}


@router.delete("/")
def delete_all_templates(db: Session = Depends(get_db)):
    updated = db.query(Template).filter(Template.is_deleted == False).update(
        {Template.is_deleted: True}
    )
    db.commit()
    return {"message": f"{updated} templates soft-deleted"}

@router.put("/{template_id}")
def update_template(
    template_id: int,
    template_data: dict,
    db: Session = Depends(get_db)
):
    template = db.query(Template).filter(Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    # === ВАЛИДАЦИЯ ПРИ ОБНОВЛЕНИИ ===
    try:
        validate_template_parameters(
            task_type=template_data.get("task_type", template.task_type),
            anatomical_area_id=template_data.get("anatomical_area_id", template.anatomical_area_id),
            parameters=template_data.get("parameters", template.parameters) or {}
        )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    # Обновляем поля
    template.name = template_data.get("name", template.name)
    template.task_type = template_data.get("task_type", template.task_type)
    template.anatomical_area_id = template_data.get("anatomical_area_id", template.anatomical_area_id)
    template.difficulty = template_data.get("difficulty", template.difficulty)
    template.language = template_data.get("language", template.language)
    template.parameters = template_data.get("parameters", template.parameters)

    db.commit()
    db.refresh(template)
    return template


@router.post("/{template_id}/generate", response_model=AssignmentResponse)
def generate_assignments(
    template_id: int, 
    count: int = 1, 
    db: Session = Depends(get_db)
):
    template = db.query(Template).filter(Template.id == template_id).first()
    if not template:
        raise HTTPException(status_code=404, detail="Template not found")

    # Пока генерируем только одно задание (позже сделаем цикл)
    assignment_data = generate_assignment_from_template(template)

    db_assignment = Assignment(
        template_id=template.id,
        task_type=template.task_type,
        anatomical_area_id=template.anatomical_area_id,
        difficulty=template.difficulty,
        language=template.language,
        parameters=template.parameters,
        data=assignment_data
    )
    db.add(db_assignment)
    db.commit()
    db.refresh(db_assignment)

    return db_assignment