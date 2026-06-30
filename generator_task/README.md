# Генератор заданий для лабораторного практикума по анатомии

Система для создания шаблонов и генерации заданий виртуального лабораторного практикума по костной анатомии.

## Описание

Данный проект представляет собой интерфейс **преподавателя** и заглушку для просмотра выполнения сгенерированных заданий от лица **студента** для:

- Создания шаблонов заданий 4 типов
- Генерации заданий по шаблонам
- Просмотра и управления созданными заданиями
- Передачи данных в визуализатор (3D-часть)

### Поддерживаемые типы заданий:
1. **Идентификация кости**
2. **Определение ориентиров**
3. **Сборка сустава**
4. **Сборка анатомической конструкции**

## Технологии

- **Frontend**: Godot Engine 4.3+
- **Backend**: FastAPI + PostgreSQL (отдельный репозиторий)
- **Язык**: GDScript + Python

## Требования

- Godot Engine **4.3** или выше
- Python 3.11+
- PostgreSQL 15+ (для backend)

## Установка и запуск

### 1. Клонирование репозитория
### 2. Открыть папку backend с помощью редактора кода, создать виртуальное окружение и активаировать его
python -m venv venv
Windows:
venv/Scripts/activate

Linux / macOS:
source venv/bin/activate
### 3. Установить зависимости
pip install -r requirements.txt

### 3. Настройка PostgreSQL:
Открыть pgAdmin или терминал PostgreSQL.
Создать БД anatomy_db

В файле .env в строке
DATABASE_URL=postgresql://postgres:1234@localhost:5432/anatomy_db

заменить пароль 1234 на свой пароль от PostgreSQL.

### 4. Применение миграции к БД
alembic upgrade head

Если миграций ещё нет, выполнить сначала
alembic revision --autogenerate -m "initial migration"
alembic upgrade head

После выполнения этих команд должны создасться таблицы:
templates
assignments
anatomical_areas
bones
joints
structures

### 5. Загрузка начальных данных
python scripts/seed_anatomy_data.py

### 6. Запуск Backend
python -m uvicorn app.main:app --reload


### 6. Запуск Backend
Открыть Godot 4.3 (или новее)
Нажмать Import и выберать папку anatomy_generator_godot
Запустить проект