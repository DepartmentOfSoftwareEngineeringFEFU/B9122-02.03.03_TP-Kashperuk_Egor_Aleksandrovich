from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime


class AssignmentResponse(BaseModel):
    id: int
    template_id: int
    task_type: str
    anatomical_area_id: int
    difficulty: Optional[int] = None
    language: str = "Русский"
    parameters: Optional[Dict[str, Any]] = None
    data: Optional[Dict[str, Any]] = None
    created_at: datetime

    class Config:
        from_attributes = True