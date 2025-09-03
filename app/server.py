# server.py
from pathlib import Path
from fastapi import FastAPI
from pydantic import BaseModel
from ultralytics import YOLO
import base64
import cv2
import numpy as np

app = FastAPI()

# Path model
MODEL_PATH = Path(__file__).resolve().parent.parent / "models" / "yolo-model.pt"
model = YOLO(str(MODEL_PATH))

# Request body schema
class FrameData(BaseModel):
    image_base64: str

@app.post("/detect")
async def detect(frame: FrameData):
    # Decode base64 → numpy image
    img_data = base64.b64decode(frame.image_base64)
    nparr = np.frombuffer(img_data, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    # Run YOLO inference
    results = model(img, conf=0.5)  # YOLO sudah punya conf filter bawaan
    detections = []
    for r in results[0].boxes:
        cls_id = int(r.cls[0])
        label = model.names[cls_id]
        conf = float(r.conf[0])

        # Filter hanya kalau confidence >= 0.7 (70%)
        if conf >= 0.5:
            bbox = r.xyxy[0].tolist()
            detections.append({
                "class": label,
                "confidence": conf,
                "bbox": bbox
            })

    return {"detections": detections}
