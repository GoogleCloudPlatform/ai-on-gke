import logging
from datetime import datetime

# Setup logging
logger = logging.getLogger('lexitrailcmd')
logger.setLevel(logging.INFO)
logger.propagate = False  # Disable propagation to avoid duplicate logs

if logger.hasHandlers():
    logger.handlers.clear()

console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)

formatter = logging.Formatter('[%(asctime)s] %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
console_handler.setFormatter(formatter)
logger.addHandler(console_handler)

def log_info(message):
    """Helper function to log with a timestamp."""
    logger.info(message)
