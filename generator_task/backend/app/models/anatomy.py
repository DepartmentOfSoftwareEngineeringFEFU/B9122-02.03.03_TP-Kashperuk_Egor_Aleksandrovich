from sqlalchemy import Column, Integer, String, ForeignKey, JSON
from sqlalchemy.orm import relationship
from app.database import Base

class AnatomicalArea(Base):
    __tablename__ = "anatomical_areas"

    id = Column(Integer, primary_key=True, index=True)
    name_ru = Column(String, nullable=False)
    name_lat = Column(String)
    name_en = Column(String)

    bones = relationship("Bone", back_populates="area")
    joints = relationship("Joint", back_populates="area")
    structures = relationship("Structure", back_populates="area")


class Bone(Base):
    __tablename__ = "bones"

    id = Column(Integer, primary_key=True, index=True)
    area_id = Column(Integer, ForeignKey("anatomical_areas.id"), nullable=False)
    name_ru = Column(String, nullable=False)
    name_lat = Column(String)
    name_en = Column(String)
    landmarks = Column(JSON)          # храним ориентиры как JSON-массив

    area = relationship("AnatomicalArea", back_populates="bones")


class Joint(Base):
    __tablename__ = "joints"

    id = Column(Integer, primary_key=True, index=True)
    area_id = Column(Integer, ForeignKey("anatomical_areas.id"))
    name_ru = Column(String, nullable=False)
    name_lat = Column(String)
    name_en = Column(String)
    bone_ids = Column(JSON)           # массив id костей
    correct_connections = Column(JSON)  # массив пар [[id1, id2], ...]
    description_ru = Column(String)

    area = relationship("AnatomicalArea", back_populates="joints")


class Structure(Base):
    __tablename__ = "structures"

    id = Column(Integer, primary_key=True, index=True)
    area_id = Column(Integer, ForeignKey("anatomical_areas.id"))
    name_ru = Column(String, nullable=False)
    name_lat = Column(String)
    name_en = Column(String)
    bone_ids = Column(JSON)
    correct_connections = Column(JSON)
    description_ru = Column(String)

    area = relationship("AnatomicalArea", back_populates="structures")