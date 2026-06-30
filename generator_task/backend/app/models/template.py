from sqlalchemy import Column, Integer, String, JSON, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base


class Template(Base):
    __tablename__ = "templates"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    task_type = Column(String, nullable=False)           # "Идентификация кости", "Сборка сустава" и т.д.
    anatomical_area_id = Column(Integer, nullable=False)
    difficulty = Column(Integer, default=1)
    language = Column(String, default="Русский")
    parameters = Column(JSON)                            # специфические параметры шаблона
    created_at = Column(DateTime, default=datetime.utcnow)

    is_deleted = Column(Boolean, default=False, nullable=False)
