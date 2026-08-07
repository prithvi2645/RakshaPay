"""Sanity-check both exported ONNX models with a couple of hand-picked examples."""
import numpy as np
import onnxruntime as ort

from generate_qr_data import shannon_entropy


def verify_risk_model():
    sess = ort.InferenceSession("ml/models/qr_risk_model.onnx")

    def features(vpa, has_amount, amount, has_keyword, known_suffix):
        local = vpa.split("@")[0]
        return [
            float(known_suffix),
            round(shannon_entropy(local), 3),
            round(sum(c.isdigit() for c in local) / max(len(local), 1), 3),
            float(len(local)),
            float(has_amount),
            float(amount),
            float(has_keyword),
        ]

    examples = {
        "legit merchant": features("rahul.sharma@okaxis", 0, 0, 0, 1),
        "random fraud vpa": features("x9k2plq7z1@okaxis", 1, 2, 1, 1),
        "unknown psp": features("kyc-team42@pay-verify", 0, 0, 1, 0),
    }
    X = np.array(list(examples.values()), dtype=np.float32)
    labels, probs = sess.run(None, {"input": X})
    for name, label, prob in zip(examples, labels, probs):
        print(f"[QR model] {name}: label={label} fraud_prob={prob[1]:.3f}")


def verify_text_model():
    sess = ort.InferenceSession("ml/models/scam_text_model.onnx")
    examples = [
        "Rs.500 debited from your account for UPI txn to City Cafe. Avl bal Rs.4200. -HDFC Bank",
        "Dear customer, your SBI KYC will be blocked in 24 hours. Update now: http://bit.ly/1234",
        "We noticed suspicious activity on your UPI account. Share the OTP sent to you to secure it.",
    ]
    X = np.array([[t] for t in examples], dtype=object)
    labels, probs = sess.run(None, {"input": X})
    for text, label, prob in zip(examples, labels, probs):
        print(f"[Text model] scam_prob={prob[1]:.3f} label={label} :: {text[:60]}...")


if __name__ == "__main__":
    verify_risk_model()
    print()
    verify_text_model()
