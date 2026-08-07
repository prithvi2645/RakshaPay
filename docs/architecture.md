# RakshaPay — Architecture Reference

Source: original "Hack Genesis 2026" deck (WTech team), extracted 2026-08-06.

## Problem

- 23.2 billion UPI transactions processed in May 2026.
- ₹981 crore lost across 12.64 lakh UPI fraud cases (FY 2024-25); ₹805 crore across
  10.64 lakh cases (FY 2025-26, up to Nov).
- 1 in 5 Indian families has faced UPI fraud in the last 3 years.
- Bank-side / NPCI systems (e.g. MuleHunter.AI) act **after** authorization — UPI's
  irreversibility makes recovery hard.

## Solution

RakshaPay is a lightweight companion layer (app + SMS listener) that sits
between the user and every UPI action, not a replacement for any UPI app, gateway, or bank.

```
PhonePe / GPay / BHIM / Paytm
            ^
        RakshaPay   <- intervenes here, before PIN entry
            ^
      Android Phone
```

## System flow

1. **User Action** — QR scan, UPI ID check, or payment SMS arrives.
2. **Input Capture Layer** — QR Scanner, SMS Analyzer. All capture
   and analysis happens on-device; nothing raw leaves the phone.
3. **On-Device AI Risk Engine**:
   - QR Structure Analysis — QR pattern/entropy/risky-characteristic checks
   - VPA / UPI-ID Analysis — UPI ID pattern and reputation checks
   - Scam Text Detection — NLP model over SMS text
   - Scam Database Matching — against local + cloud scam-pattern cache
   - Lightweight ML models, on-device inference only
4. **Risk Score & Alert** — Safe (low risk) / Caution (medium risk) / High-Risk (recommend
   block), each with a text explanation, voice alert in the user's regional language, and
   safety tips.
5. **User Decision & Feedback Loop** — proceed, cancel/block, or report as scam (optional).
   Reports strengthen the shared scam database for all users.
6. **Cloud Scam Intelligence Database** — stores anonymized scam patterns, updates synced
   to all devices, privacy-focused (no sensitive data shared).

## Tech stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Android) |
| On-device inference | ONNX Runtime Mobile (QR/VPA model); TF-IDF + logistic evaluated directly in Dart (text model) |
| Risk Scoring Model | XGBoost or Random Forest over structural QR/VPA features, trained offline |
| NLP Scam-Text Matcher | Keyword + pattern hybrid (TF-IDF/LogReg) — the deck's stated alternative to a full distilled transformer |
| Text-to-Speech | On-device regional-language TTS (Android TTS engine) |
| Backend | Supabase (Postgres + RLS + trigger) — scam-database sync, reports, risk logs only; never used for scoring |

## Design principles

- **On-device first** — most analysis happens on the phone.
- **Privacy protected** — raw SMS and QR content never leaves the device;
  only anonymized, derived signals sync to the backend.
- **Real-time** — risk scored instantly, before UPI PIN entry.
- **Community-powered** — reported scams improve detection for everyone.
- **Offline-first** — on-device models keep working with no connectivity; cloud sync is
  best-effort.

## This build's scope decisions



- Platform: **Android only** (SMS access is not available on iOS).
- Backend: **Supabase** (Postgres + RLS + trigger), live, not localhost-only. Report
  aggregation is an `AFTER INSERT` trigger running inside the database, so there is no
  separate runtime to deploy or keep awake.
- Scope: full end-to-end MVP — real backend, multi-language voice alerts, scam-pattern/
  report/risk-log collection all functional, not stubbed.
- Input capture: **QR scanning and SMS**.
- Training data — revised 2026-08-06 after review:
  - **Scam-text model**: real backbone. UCI SMS Spam Collection (5,574 human-written
    SMS) + ~1,200 synthetic rows for India/UPI-specific patterns absent from that
    corpus. Metrics are reported on held-out **real** messages only; scoring against
    synthetic rows drawn from the training templates measures template inversion, not
    generalization.
  - **QR/VPA model**: synthetic only, and disclosed as a limitation. No public dataset
    of fraudulent UPI QR payloads or VPA strings exists. Kaggle's "UPI fraud" datasets
    are transaction-level (amount, timestamp, merchant category) for *post-transaction*
    anomaly detection and carry no QR/VPA string to score pre-transaction.

## Implementation notes

- **Risk model**: RandomForest rather than XGBoost — it converts to ONNX through
  skl2onnx with no extra converter dependency, which keeps the mobile inference path
  simple. Both were listed as acceptable in the deck.
- **Text model ships as JSON weights, not ONNX**: the Dart `onnxruntime` binding has
  patchy support for string input tensors. The pipeline is linear (TF-IDF →
  LogisticRegression), so evaluating the vocabulary, IDF weights and coefficients
  directly in Dart is numerically exact, not an approximation, and removes a real
  on-device failure mode. The QR model stays ONNX (float tensors work reliably).
- **Offline-first is enforced in code**: `ScamDatabaseService` resolves
  `Supabase.instance.client` lazily and returns null when the backend is unavailable, so
  a failed init can never prevent the user from scoring a payment. The local cache and
  the offline report queue are hand-rolled on `SharedPreferences` rather than relying on
  any SDK's built-in persistence. Feature
  extraction in `qr_risk_analyzer.dart` must stay in lockstep with the `FEATURES` list
  in `ml/src/train_risk_model.py` — `app/test/qr_features_test.dart` guards the order.
- **Report poisoning**: a reported VPA only becomes an active shared pattern after
  crossing a 3-report threshold in the aggregation trigger, so one bad-faith report
  cannot flag a legitimate merchant for every user.
  - The threshold counts **distinct devices**, enforced by a `UNIQUE (vpa, device_hash)`
    constraint on `reports` — the database rejects a second report of the same VPA from
    the same install, so three taps from one phone count once, not three times.
    `device_hash` is a random per-install token from `Random.secure()`, not a hardware or
    advertising ID, so it groups reports without identifying the user or the handset.
