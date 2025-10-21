"""ML training placeholder (no heavy deps)."""

def train_dummy_model(data=None):
    # Placeholder for training logic
    return {"model": "dummy", "version": 1}

if __name__ == "__main__":
    model = train_dummy_model()
    print("Trained model:", model)
