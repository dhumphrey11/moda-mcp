"""ML inference placeholder (no heavy deps)."""

def predict_dummy(model, features=None):
    # Always return neutral prediction
    return {"score": 0.0, "label": "hold"}

if __name__ == "__main__":
    out = predict_dummy({"model": "dummy"})
    print("Inference output:", out)
