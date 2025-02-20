# inference_server.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import torch
from transformers import AutoModel, PreTrainedTokenizer, EsmConfig
import logging
import os

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

class CustomEsmTokenizer(PreTrainedTokenizer):
    def __init__(self, **kwargs):
        # Initialize vocabulary first
        self.vocab = [
            "<pad>", "<mask>", "<cls>", "<sep>", "<unk>",
            "L", "A", "G", "V", "S", "E", "R", "T", "I", "D",
            "P", "K", "Q", "N", "F", "Y", "M", "H", "W", "C",
            "X", "B", "U", "Z", "O", ".", "-", "*"
        ]
        self.ids_to_tokens = dict(enumerate(self.vocab))
        self.tokens_to_ids = {tok: i for i, tok in enumerate(self.vocab)}
        
        # Set special token attributes
        kwargs["pad_token"] = "<pad>"
        kwargs["mask_token"] = "<mask>"
        kwargs["cls_token"] = "<cls>"
        kwargs["sep_token"] = "<sep>"
        kwargs["unk_token"] = "<unk>"
        
        # Now call parent constructor
        super().__init__(**kwargs)

    def get_vocab(self):
        return self.tokens_to_ids.copy()
        
    def _tokenize(self, text):
        return list(text.strip().upper())
        
    def _convert_token_to_id(self, token):
        return self.tokens_to_ids.get(token, self.tokens_to_ids["<unk>"])
        
    def _convert_id_to_token(self, index):
        return self.ids_to_tokens.get(index, "<unk>")
        
    def convert_tokens_to_string(self, tokens):
        return "".join(tokens)
        
    @property
    def vocab_size(self):
        return len(self.vocab)
        
    def save_vocabulary(self, save_directory):
        vocab_file = os.path.join(save_directory, "vocab.txt")
        with open(vocab_file, "w") as f:
            f.write("\n".join(self.vocab))
        return (vocab_file,)

class InferenceRequest(BaseModel):
    sequence: str

@app.on_event("startup")
async def load_model():
    global model, tokenizer, config
    try:
        model_path = os.getenv("MODEL_PATH", "/mnt/data/model")
        logger.info(f"Loading model from {model_path}")
        
        # Load config
        config = EsmConfig.from_pretrained(model_path)
        logger.info(f"Model config loaded: vocab_size={config.vocab_size}")
        
        # Create custom tokenizer
        tokenizer = CustomEsmTokenizer()
        logger.info(f"Created custom tokenizer with vocab size: {tokenizer.vocab_size}")
        
        # Load model
        model = AutoModel.from_pretrained(model_path)
        model = model.eval()
        
        if torch.cuda.is_available():
            model = model.cuda()
            logger.info("Model loaded on GPU")
        
        # Test tokenization
        test_seq = "MKTV"
        test_tokens = tokenizer(
            test_seq,
            return_tensors="pt",
            padding=True,
            truncation=True
        )
        logger.info(f"Test tokenization shape: {test_tokens['input_ids'].shape}")
        logger.info(f"Test token values: {test_tokens['input_ids'].tolist()}")
        
        logger.info("Model and tokenizer loaded successfully")
        
    except Exception as e:
        logger.error(f"Error loading model: {str(e)}")
        if os.path.exists(model_path):
            logger.error(f"Directory contents: {os.listdir(model_path)}")
        raise RuntimeError(f"Failed to load model: {str(e)}")

@app.post("/predict")
async def predict(request: InferenceRequest):
    try:
        # Validate input
        if not request.sequence or len(request.sequence.strip()) == 0:
            raise HTTPException(status_code=400, detail="Empty sequence provided")

        logger.info(f"Processing sequence of length: {len(request.sequence)}")

        # Tokenize
        inputs = tokenizer(
            request.sequence,
            return_tensors="pt",
            padding=True,
            truncation=True,
            max_length=1024
        )
        
        # Remove token_type_ids as ESM doesn't use them
        if 'token_type_ids' in inputs:
            del inputs['token_type_ids']
            
        logger.info(f"Tokenized shape: {inputs['input_ids'].shape}")

        # Move to GPU if available
        if torch.cuda.is_available():
            inputs = {k: v.cuda() for k, v in inputs.items()}

        # Perform inference
        with torch.no_grad():
            outputs = model(**inputs)
        
        # Get embeddings from last hidden state
        embeddings = outputs.last_hidden_state.mean(dim=1)
        
        return {
            "embeddings": embeddings.cpu().numpy().tolist()[0],
            "sequence_length": len(request.sequence),
            "input_length": inputs['input_ids'].shape[1]
        }

    except Exception as e:
        logger.error(f"Inference error: {str(e)}")
        logger.error("Detailed traceback:", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Inference failed: {str(e)}"
        )

    except Exception as e:
        logger.error(f"Inference error: {str(e)}")
        logger.error("Detailed traceback:", exc_info=True)
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