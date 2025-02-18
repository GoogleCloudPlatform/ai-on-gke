from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
from transformers import AutoModelForSequenceClassification, AutoTokenizer
import logging
from typing import Dict, List
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="ESM2 Inference API", version="1.0.0")

class InferenceRequest(BaseModel):
    sequence: str

class InferenceResponse(BaseModel):
    predictions: List[float]
    sequence_length: int

# Global variables for model and tokenizer
model = None
tokenizer = None

@app.on_event("startup")
async def load_model():
    """Load model and tokenizer on startup."""
    global model, tokenizer
    try:
        model_path = os.getenv("MODEL_PATH", "/app/model")
        logger.info(f"Loading model from {model_path}")
        
        model = AutoModelForSequenceClassification.from_pretrained(model_path)
        model = model.eval()
        
        if torch.cuda.is_available():
            model = model.to('cuda')
            logger.info("Model loaded on GPU")
        else:
            logger.warning("GPU not available, using CPU")
            
        tokenizer = AutoTokenizer.from_pretrained(model_path)
        logger.info("Model and tokenizer loaded successfully")
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        raise RuntimeError("Failed to load model")

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    if model is None or tokenizer is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "healthy"}

@app.post("/predict", response_model=InferenceResponse)
async def predict(request: InferenceRequest):
    """
    Predict endpoint for sequence inference.
    """
    try:
        # Input validation
        if not request.sequence or len(request.sequence.strip()) == 0:
            raise HTTPException(status_code=400, detail="Empty sequence provided")

        # Tokenize input
        inputs = tokenizer(
            request.sequence,
            return_tensors="pt",
            truncation=True,
            max_length=512
        )
        
        # Move inputs to GPU if available
        if torch.cuda.is_available():
            inputs = {k: v.cuda() for k, v in inputs.items()}

        # Perform inference
        with torch.no_grad():
            outputs = model(**inputs)
        
        predictions = outputs.logits.softmax(dim=-1)
        
        # Move predictions back to CPU for JSON serialization
        predictions_list = predictions.cpu().numpy().tolist()[0]

        return InferenceResponse(
            predictions=predictions_list,
            sequence_length=len(request.sequence)
        )

    except Exception as e:
        logger.error(f"Inference error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Inference failed: {str(e)}"
        )

@app.on_event("shutdown")
async def cleanup():
    """Cleanup resources on shutdown."""
    global model, tokenizer
    model = None
    tokenizer = None
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
    logger.info("Cleaned up resources")