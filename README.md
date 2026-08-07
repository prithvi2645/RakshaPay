# RakshaPay

A pre-transaction fraud shield for UPI users. RakshaPay is a companion layer that sits
beside existing UPI apps (Google Pay, PhonePe, BHIM, Paytm) and scores the fraud risk of a
QR scan, a UPI ID, or a payment SMS **before** the user enters their UPI PIN.

It does not process payments, hold funds, or replace any UPI app or bank. It only reads
locally available signals (QR payload, VPA string, SMS text), scores risk on-device, and
warns the user in their own language.

## Repository layout

```
app/       Flutter Android app (input capture, on-device inference, alert UI, TTS)
ml/        Python training pipeline for the two on-device models
backend/   Supabase Postgres schema, trigger + RLS (scam-pattern sync, reports, risk logs)
docs/      Architecture notes and the original hackathon deck extraction
```

## Architecture

1. **User Action** — user scans a QR, enters a UPI ID to check, or gets a payment SMS
2. **Input Capture Layer** (Android, on-device) — QR scanner and SMS reader. All raw data
   stays on the device.
3. **On-Device AI Risk Engine** — two models run locally:
   - **Risk Scoring Model** (RandomForest → ONNX): structural features of the
     QR payload / VPA string (entropy, known-PSP-suffix check, pre-filled amount, etc.)
   - **NLP Scam-Text Matcher** (TF-IDF + LogisticRegression): scans SMS text for scam
     phrasing
   Both are cross-checked against a locally cached copy of the community scam-pattern
   database.
4. **Risk Score & Alert** — Safe / Caution / High-Risk, with an on-screen explanation and
   a spoken alert in English, Hindi, Kannada or Marathi (`en-IN`, `hi-IN`, `kn-IN`,
   `mr-IN`). On-screen reason text is English only for now.
5. **User Decision & Feedback Loop** — proceed, cancel, or report. Reports and anonymized
   risk-scoring events sync to the backend.
6. **Cloud Scam Intelligence Database** (Supabase) — anonymized, community-sourced scam
   patterns, synced back down to all devices.

See [docs/architecture.md](docs/architecture.md) for the full design.

## Training data

**The scam-text model is trained on real data.** The backbone is the
[UCI SMS Spam Collection](https://archive.ics.uci.edu/dataset/228/sms+spam+collection) —
5,574 human-written SMS labeled ham/spam. That corpus is UK/2011 general SMS spam and
contains no UPI traffic at all, so ~1,200 synthetic rows are added for India/UPI-specific
patterns it lacks: KYC-expiry lures, UPI-PIN requests, remote-access (AnyDesk) scams, and
legitimate UPI debit/credit alerts.

Reported metrics are measured on **held-out real messages only**. Scoring against
synthetic rows generated from the same templates the model trained on would measure
template inversion, not generalization.

Current held-out performance on 1,115 real, unseen messages:

| class | precision | recall | f1 | support |
|---|---|---|---|---|
| ham | 0.99 | 0.99 | 0.99 | 966 |
| scam | 0.97 | 0.97 | 0.97 | 149 |

**The QR/VPA model is trained on synthetic data**, and this is a genuine limitation.
No public dataset of fraudulent UPI QR payloads or VPA strings exists. The Kaggle "UPI
fraud" datasets are transaction-level (amount, timestamp, merchant category, device) and
are built for *post-transaction* anomaly detection — they have no column for the QR
payload or VPA string that RakshaPay scores *before* a transaction exists.

## Setup

### ML pipeline

```bash
cd ml
python -m venv venv
./venv/Scripts/python.exe -m pip install -r requirements.txt
```

Then, from the repository root:

```bash
python ml/src/download_datasets.py      # fetch the real UCI SMS corpus
python ml/src/generate_qr_data.py       # synthesize QR/VPA structural data
python ml/src/build_text_dataset.py     # real + synthetic hybrid text set
python ml/src/train_risk_model.py       # -> ml/models/qr_risk_model.onnx
python ml/src/train_text_model.py       # -> ml/models/scam_text_model.onnx
python ml/src/export_text_weights.py    # -> app/assets/models/scam_text_model.json
python ml/src/verify_models.py          # sanity-check both exports
```

The QR model ships to the app as ONNX. The text model ships as JSON weights instead:
the Dart `onnxruntime` binding has patchy support for string input tensors, and the
model is linear, so evaluating it directly in Dart is exact rather than an approximation.

### App

Backend credentials are injected at build time and never committed. Copy the template
and fill in your own Supabase project values:

```bash
cd app
cp env.example.json env.json
```

`env.json` is gitignored. Use the **publishable** key, never a `service_role`/secret key —
the latter bypasses every RLS policy.

```bash
flutter pub get
flutter test
flutter build apk --debug --dart-define-from-file=env.json
```

Without `env.json` the app still builds and runs; it simply has no community sync, since
all scoring happens on-device.

### Backend

No CLI or deploy step. Open the Supabase dashboard → **SQL Editor**, paste
`backend/supabase/schema.sql`, and run it. The script is idempotent, so re-running it
after a change is safe.

The aggregation that turns reports into shared scam patterns is a Postgres trigger, so it
lives inside the database — there is no server to deploy, bill, or keep awake.

## Privacy

Raw QR payloads and SMS bodies never leave the device. The only data that syncs upward is:

- **Reports** you explicitly submit — the payee VPA and a reason code, nothing else.
- **Risk logs** — risk level and score only, no content.

Row Level Security policies (`backend/supabase/schema.sql`) enforce this server-side:
reports are insert-only and cannot be read back by clients, and the shared scam-pattern
table is read-only to devices, written only by the aggregation trigger after a VPA crosses
a 3-report threshold so a single bad-faith report cannot poison it.

Reports carry a random per-install token rather than an account or device ID. It exists
only so the threshold can count *distinct devices* — a `UNIQUE (vpa, device_hash)`
constraint means the same phone reporting the same VPA three times counts once, not three
times. The token identifies nothing about the user or the handset and is discarded on
uninstall.
