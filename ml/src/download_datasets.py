"""Fetch the real public datasets the training pipeline depends on.

Currently just the UCI SMS Spam Collection (5,574 real human-written SMS,
labeled ham/spam). Run once before build_text_dataset.py.
"""
import urllib.request
import zipfile
from pathlib import Path

RAW_DIR = Path("ml/data/raw")
UCI_SMS_URL = "https://archive.ics.uci.edu/static/public/228/sms+spam+collection.zip"


def download_uci_sms():
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    target = RAW_DIR / "SMSSpamCollection"
    if target.exists():
        print(f"{target} already present, skipping download")
        return

    zip_path = RAW_DIR / "smsspamcollection.zip"
    print(f"Downloading {UCI_SMS_URL} ...")
    urllib.request.urlretrieve(UCI_SMS_URL, zip_path)
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(RAW_DIR)
    print(f"Extracted to {target}")


if __name__ == "__main__":
    download_uci_sms()
