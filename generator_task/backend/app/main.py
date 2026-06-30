from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.config import get_settings
from app.routers import templates, assignments, anatomy
from app.models import template, assignment, anatomy as anatomy_models


app = FastAPI(title="Anatomy Lab Generator API")


settings = get_settings()

app = FastAPI(
    title="Anatomy Generator API",
    description="Backend для генератора заданий виртуального лабораторного практикума по анатомии",
    version="0.1.0",
    debug=settings.DEBUG
)

# Подключаем роутеры
app.include_router(templates.router)
app.include_router(assignments.router) 
app.include_router(anatomy.router)

@app.get("/")
def root():
    return {"message": "Anatomy Generator API is running"} 


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"detail": exc.detail}
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors()}
    )