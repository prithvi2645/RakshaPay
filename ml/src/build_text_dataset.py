"""Build the scam-text training set as a hybrid of real and synthetic data.

Backbone: the UCI SMS Spam Collection (5,574 real human-written SMS, ham/spam).
Download once with `python ml/src/download_datasets.py`.

That corpus is UK/2011 general SMS spam. It teaches the model what real scam
language looks like, but it contains no UPI content at all — no KYC-expiry
lures, no UPI-PIN requests, no remote-access (AnyDesk) scams, and no legitimate
UPI debit/credit alerts. Those India-specific classes are added
synthetically so the model has any signal for them at all.

Every row is tagged with `origin` (real|synthetic) so training can evaluate on a
REAL-ONLY held-out set. Scoring a model on synthetic rows it was trained to
invert produces a meaningless accuracy number.
"""
import csv
import random
from pathlib import Path

random.seed(42)

RAW_PATH = Path("ml/data/raw/SMSSpamCollection")
OUT_PATH = Path("ml/data/scam_text_dataset.csv")

BANKS = ["SBI", "HDFC Bank", "ICICI Bank", "Axis Bank", "Paytm", "PhonePe", "Google Pay"]
NAMES = ["Rahul", "Priya", "Amit", "Sunita", "Vikram", "Anjali"]

# India/UPI-specific scam patterns absent from the UCI corpus.
UPI_SCAM_TEMPLATES = [
    "Dear customer, your {bank} KYC will be blocked in 24 hours. Update now: {link}",
    "URGENT: Your {bank} account will be suspended. Verify immediately at {link}",
    "Your KYC has expired. Update immediately or your account will be permanently blocked: {link}",
    "We noticed suspicious activity on your UPI account. Share the OTP sent to you to secure it.",
    "This is {bank} support. Please install AnyDesk and share your screen so we can process your refund.",
    "Dear user, download TeamViewer QuickSupport so our agent can fix your failed UPI transaction.",
    "You are eligible for a cashback of Rs.{amount}. Enter your UPI PIN in the linked app to claim.",
    "Customer care regarding your refund of Rs.{amount}. Please share your UPI PIN to process it.",
    "Your electricity bill payment failed. To avoid disconnection pay via {link} or call {phone}",
    "Congratulations! You won Rs.{amount} lottery. Send Rs.{fee} processing fee via UPI to claim.",
    "Your parcel is held at customs. Pay Rs.{fee} customs fee via this UPI link to release: {link}",
    "I have sent Rs.{amount} to your account by mistake. Please accept the collect request to return it.",
    "Scan this QR code to RECEIVE your refund of Rs.{amount} and enter your UPI PIN to confirm.",
    "Army officer posted here, urgent purchase. Accept my UPI collect request for Rs.{amount} advance.",
]

# Legitimate UPI alerts — the UCI corpus has no UPI traffic, so without
# these the model would treat any UPI-shaped message as suspicious.
UPI_LEGIT_TEMPLATES = [
    "Rs.{amount} debited from a/c **{acct} for UPI txn to {name}. Avl bal Rs.{bal}. -{bank}",
    "Rs.{amount} credited to a/c **{acct} via UPI from {name}. Avl bal Rs.{bal}. -{bank}",
    "Rs.{amount} sent to {name} via UPI. Txn ID {txn}. -{bank}",
    "UPI mandate of Rs.{amount} to {name} is due on 15th. -{bank}",
    "Your {bank} UPI PIN was changed successfully. Not you? Call 1800{phone4}.",
    "Payment of Rs.{amount} to {name} was successful. UPI Ref {txn}.",
    "Your OTP for {bank} login is {otp}. Do not share this with anyone.",
    "Rs.{amount} debited for {name} autopay. Avl bal Rs.{bal}. -{bank}",
]


def fill(template):
    return template.format(
        bank=random.choice(BANKS),
        name=random.choice(NAMES + ["City Cafe", "Sharma Kirana", "Om Traders"]),
        link=f"http://{random.choice(['bit.ly', 'tinyurl.com', 'rb.gy'])}/{random.randint(1000, 9999)}",
        phone=f"9{random.randint(100000000, 999999999)}",
        phone4=random.randint(1000, 9999),
        amount=random.randint(100, 50000),
        fee=random.randint(10, 999),
        bal=random.randint(500, 100000),
        acct=random.randint(1000, 9999),
        txn=random.randint(100000000, 999999999),
        otp=random.randint(100000, 999999),
    )


def load_real():
    if not RAW_PATH.exists():
        raise SystemExit(
            f"Missing {RAW_PATH}. Run: python ml/src/download_datasets.py"
        )
    rows = []
    with RAW_PATH.open(encoding="latin-1") as f:
        for line in f:
            line = line.strip()
            if not line or "\t" not in line:
                continue
            label, text = line.split("\t", 1)
            rows.append({"text": text, "label": int(label == "spam"), "origin": "real"})
    return rows


def build_synthetic(n_scam=600, n_legit=600):
    rows = [{"text": fill(random.choice(UPI_SCAM_TEMPLATES)), "label": 1, "origin": "synthetic"}
            for _ in range(n_scam)]
    rows += [{"text": fill(random.choice(UPI_LEGIT_TEMPLATES)), "label": 0, "origin": "synthetic"}
             for _ in range(n_legit)]
    return rows


def main():
    real = load_real()
    synthetic = build_synthetic()
    rows = real + synthetic
    random.shuffle(rows)

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["text", "label", "origin"])
        writer.writeheader()
        writer.writerows(rows)

    n_real_spam = sum(r["label"] for r in real)
    print(f"real:      {len(real):5d} rows ({n_real_spam} spam / {len(real) - n_real_spam} ham)")
    print(f"synthetic: {len(synthetic):5d} rows (UPI-specific augmentation)")
    print(f"total:     {len(rows):5d} rows -> {OUT_PATH}")


if __name__ == "__main__":
    main()
