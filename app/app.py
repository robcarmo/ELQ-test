from fastapi import FastAPI
from fastapi.responses import JSONResponse
import os

app = FastAPI()

@app.get("/health")
def health():
    return JSONResponse(content={"status": "healthy",
"version": os.getenv("APP_VERSION", "1.0.0")})

@app.get("/api/hello")
def hello():
    return JSONResponse(content={"message": "Hello from Eloquent AI!", "environment": os.getenv("ENVIRONMENT", "unknown")})

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
