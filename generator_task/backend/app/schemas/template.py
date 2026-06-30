from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime


class TemplateCreate(BaseModel):
    name: str
    task_type: str
    anatomical_area_id: int
    difficulty: int = 1
    language: str = "Русский"
    parameters: Optional[Dict[str, Any]] = None


class TemplateResponse(BaseModel):
    id: int
    name: str
    task_type: str
    anatomical_area_id: int
    difficulty: int
    language: str
    parameters: Optional[Dict[str, Any]] = None
    created_at: datetime

    class Config:
        from_attributes = True