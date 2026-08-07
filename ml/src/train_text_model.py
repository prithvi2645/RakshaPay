"""Train the NLP scam-text matcher (TF-IDF + Logistic Regression) and export to ONNX.

Evaluation note: the test split is REAL messages only. Synthetic UPI rows are
training-time augmentation, and scoring against text generated from the same
templates the model was trained on measures template inversion, not
generalization. The headline metrics below are therefore on human-written SMS
the model never saw.
"""
import json
from pathlib import Path

import joblib
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import classification_report, confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import StringTensorType


def main(
    data_path="ml/data/scam_text_dataset.csv",
    model_out="ml/models/scam_text_model.onnx",
    meta_out="ml/models/scam_text_model.meta.json",
):
    df = pd.read_csv(data_path)
    real = df[df["origin"] == "real"]
    synthetic = df[df["origin"] == "synthetic"]

    # Hold out real messages only — that is the honest generalization test.
    real_train, real_test = train_test_split(
        real, test_size=0.2, random_state=42, stratify=real["label"]
    )
    train = pd.concat([real_train, synthetic]).sample(frac=1, random_state=42)

    pipeline = Pipeline([
        (
            "tfidf",
            TfidfVectorizer(
                lowercase=True,
                ngram_range=(1, 2),
                min_df=2,
                max_features=5000,
                sublinear_tf=True,
                # skl2onnx's tokenizer doesn't support \b word-boundary regex;
                # use a plain alnum token pattern instead.
                token_pattern=r"[a-zA-Z0-9]+",
            ),
        ),
        ("clf", LogisticRegression(max_iter=1000, C=5.0, class_weight="balanced")),
    ])
    pipeline.fit(train["text"], train["label"])

    y_pred = pipeline.predict(real_test["text"])
    print("=== Held-out REAL messages (never seen, human-written) ===")
    print(classification_report(real_test["label"], y_pred, target_names=["ham", "scam"]))
    tn, fp, fn, tp = confusion_matrix(real_test["label"], y_pred).ravel()
    print(f"true_neg={tn}  false_pos={fp}  false_neg={fn}  true_pos={tp}")
    print(f"\nTrained on {len(train)} rows ({len(real_train)} real + {len(synthetic)} synthetic UPI)")

    onnx_model = convert_sklearn(
        pipeline,
        initial_types=[("input", StringTensorType([None, 1]))],
        options={id(pipeline.named_steps["clf"]): {"zipmap": False}},
        target_opset=17,
    )

    out = Path(model_out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("wb") as f:
        f.write(onnx_model.SerializeToString())
    print(f"\nWrote ONNX model to {out}")

    joblib.dump(pipeline, out.with_suffix(".joblib"))

    meta = {
        "input_shape": "[N, 1] string tensor, one raw SMS string per row",
        "output_names": [o.name for o in onnx_model.graph.output],
        "classes": pipeline.named_steps["clf"].classes_.tolist(),
        "note": "output[1] gives per-class probabilities; scam is class label 1",
        "training_data": {
            "real_source": "UCI SMS Spam Collection (5,574 human-written SMS)",
            "synthetic_rows": int(len(synthetic)),
            "synthetic_purpose": "India/UPI-specific patterns absent from the UCI corpus",
            "eval_note": "metrics measured on held-out REAL messages only",
        },
    }
    Path(meta_out).write_text(json.dumps(meta, indent=2))
    print(f"Wrote metadata to {meta_out}")


if __name__ == "__main__":
    main()
