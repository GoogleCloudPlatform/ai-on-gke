import os
import mlflow
from fastapi import FastAPI

app = FastAPI()

MODEL_PATH = os.getenv("MODEL_PATH", "")
model = mlflow.transformers.load_model(MODEL_PATH)


@app.get("/predict")
async def predict(message: str):
    return model.predict(message)
