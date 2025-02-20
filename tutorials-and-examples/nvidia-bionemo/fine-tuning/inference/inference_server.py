from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
from transformers import (
    AutoModelForSequenceClassification, 
    EsmTokenizer, 
    AutoConfig 
)
import logging
from typing import Dict, List
import os

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="ESM2 Inference API", version="1.0.0")

class InferenceRequest(BaseModel):
    sequence: str

class InferenceResponse(BaseModel):
    predictions: List[float]
    sequence_length: int

model = None
tokenizer = None

@app.on_event("startup")
async def load_model():
    """Load model and tokenizer on startup."""
    global model, tokenizer
    try:
        model_path = os.getenv("MODEL_PATH", "/mnt/data/model")
        logger.info(f"Loading model from {model_path}")
        
        # Verify the model path and files
        vocab_file = os.path.join(model_path, "vocab.txt")
        if not os.path.exists(vocab_file):
            raise FileNotFoundError(f"Vocabulary file not found at {vocab_file}")
        
        logger.info("Loading tokenizer with existing vocabulary file")
        # Initialize tokenizer with existing vocab file
        tokenizer = EsmTokenizer(
            vocab_file=vocab_file,
            do_lower_case=False,
            model_max_length=1024
        )
        
        # Load model configuration
        config = AutoConfig.from_pretrained(
            model_path,
            num_labels=1,
            problem_type="regression"
        )
        
        logger.info("Loading model with configuration")
        model = AutoModelForSequenceClassification.from_pretrained(
            model_path,
            config=config
        )
        model.eval()
        
        if torch.cuda.is_available():
            model = model.to('cuda')
            logger.info("Model loaded on GPU")
        else:
            logger.info("GPU not available, using CPU")
            
        logger.info("Model and tokenizer loaded successfully")
        
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        logger.exception("Detailed traceback:")
        raise RuntimeError(f"Failed to load model: {str(e)}")

@app.post("/predict", response_model=InferenceResponse)
async def predict(request: InferenceRequest):
    """Predict endpoint for sequence inference."""
    try:
        if not request.sequence or len(request.sequence.strip()) == 0:
            raise HTTPException(status_code=400, detail="Empty sequence provided")

        # Validate and preprocess sequence
        sequence = request.sequence.strip().upper()
        valid_amino_acids = set("ACDEFGHIKLMNPQRSTVWY")
        if not all(aa in valid_amino_acids for aa in sequence):
            raise HTTPException(
                status_code=400,
                detail="Invalid amino acid sequence. Only standard amino acids are allowed."
            )

        # Tokenize with ESM-specific settings
        inputs = tokenizer(
            sequence,
            return_tensors="pt",
            truncation=True,
            max_length=1024,
            padding=True,
            add_special_tokens=True
        )
        
        logger.info(f"Input sequence length: {len(sequence)}")
        logger.info(f"Tokenized shape: {inputs['input_ids'].shape}")

        # Use CPU for inference to avoid CUDA issues
        with torch.no_grad():
            outputs = model.cpu()(**{k: v.cpu() for k, v in inputs.items()})
            
        # Move model back to GPU if available
        if torch.cuda.is_available():
            model.cuda()

        # Handle regression output
        predictions = outputs.logits.squeeze()
        predictions_list = [float(predictions.item())] if predictions.dim() == 0 else [float(x) for x in predictions.tolist()]

        return InferenceResponse(
            predictions=predictions_list,
            sequence_length=len(sequence)
        )

    except Exception as e:
        logger.error(f"Inference error: {str(e)}")
        logger.exception("Detailed traceback:")
        raise HTTPException(
            status_code=500,
            detail=f"Inference failed: {str(e)}"
        )

@app.get("/health")
async def health_check():
    """Health check endpoint."""
    if model is None or tokenizer is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "healthy"}

@app.on_event("shutdown")
async def cleanup():
    """Cleanup resources on shutdown."""
    global model, tokenizer
    model = None
    tokenizer = None
    if torch.cuda.is_available():
        torch.cuda.empty_cache()
    logger.info("Cleaned up resources")