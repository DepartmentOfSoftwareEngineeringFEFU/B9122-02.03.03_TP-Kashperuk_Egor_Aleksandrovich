from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Optional
from app.database import get_db
from app.models.assignment import Assignment
from app.schemas.assignment import AssignmentResponse

router = APIRouter(
    prefix="/assignments",
    tags=["Assignments"]
)

"""
@router.get("/", response_model=list[AssignmentResponse])
def get_all_assignments(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    assignments = db.query(Assignment).offset(skip).limit(limit).all()
    return assignments
"""

@router.get("/", response_model=list[AssignmentResponse])
def get_assignments(
    skip: int = 0,
    limit: int = 100,
    task_type: Optional[str] = Query(None),
    anatomical_area_id: Optional[int] = Query(None),
    difficulty: Optional[int] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(Assignment)

    # === ГЛАВНОЕ ИЗМЕНЕНИЕ: показываем только неудалённые задания ===
    query = query.filter(Assignment.is_deleted == False)

    if task_type:
        query = query.filter(Assignment.task_type == task_type)
    if anatomical_area_id:
        query = query.filter(Assignment.anatomical_area_id == anatomical_area_id)
    if difficulty:
        query = query.filter(Assignment.difficulty == difficulty)

    return query.offset(skip).limit(limit).all()


@router.delete("/{assignment_id}")
def delete_assignment(assignment_id: int, db: Session = Depends(get_db)):
    assignment = db.query(Assignment).filter(
        Assignment.id == assignment_id,
        Assignment.is_deleted == False
    ).first()

    if not assignment:
        raise HTTPException(status_code=404, detail="Assignment not found")

    assignment.is_deleted = True
    db.commit()
    return {"message": "Assignment soft-deleted successfully"}

@router.delete("/")
def delete_all_assignments(db: Session = Depends(get_db)):
    updated_count = db.query(Assignment).filter(
        Assignment.is_deleted == False
    ).update({Assignment.is_deleted: True})

    db.commit()
    return {"message": f"{updated_count} assignments soft-deleted"}