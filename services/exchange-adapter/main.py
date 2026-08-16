import logging
import os
import time

# Configure logging
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)
logger = logging.getLogger("exchange-adapter")


def main():
    logger.info("Starting Exchange Adapter (Placeholder)")

    while True:
        logger.info("alive")
        time.sleep(10)


if __name__ == "__main__":
    main()
