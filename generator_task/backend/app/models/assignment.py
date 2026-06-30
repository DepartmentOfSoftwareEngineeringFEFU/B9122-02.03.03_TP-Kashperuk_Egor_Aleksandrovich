from sqlalchemy import Column, Integer, String, JSON, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
from app.database import Base


class Assignment(Base):
    __tablename__ = "assignments"

    id = Column(Integer, primary_key=True, index=True)
    template_id = Column(Integer, ForeignKey("templates.id"), nullable=False)
    task_type = Column(String, nullable=False)
    anatomical_area_id = Column(Integer, nullable=False)
    difficulty = Column(Integer)
    language = Column(String, default="Русский", nullable=False)
    parameters = Column(JSON)                    # параметры, с которыми было сгенерировано задание
    data = Column(JSON)                          # сами данные задания (кости, соединения и т.д.)
    created_at = Column(DateTime, default=datetime.utcnow)

    is_deleted = Column(Boolean, default=False, nullable=False)

    # Связь с шаблоном
    template = relationship("Template", backref="assignments")