import time
import logging
import random

# Simple log generator for PoC
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] app=%(name)s env=local msg="%(message)s"',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler("/tmp/app.log")
    ]
)

logger = logging.getLogger("poc-app")

messages = [
    "User logged in",
    "Payment processed successfully",
    "Error communicating with the database",
    "Processing a new order",
    "Shopping cart was emptied"
]

if __name__ == "__main__":
    while True:
        msg = random.choice(messages)
        level = random.choice([logging.INFO, logging.INFO, logging.INFO, logging.WARNING, logging.ERROR])
        logger.log(level, msg)
        time.sleep(2)
