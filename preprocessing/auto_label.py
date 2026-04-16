import os
import cv2
import random
from tqdm import tqdm
from ultralytics import YOLO
import matplotlib.pyplot as plt

def save_yolo_labels(boxes, label_path: str):
    """Save bounding boxes in YOLO format: class cx cy w h"""
    with open(label_path, "w") as f:
        for box in boxes:
            cx, cy, bw, bh = box
            f.write(f"0 {cx:.6f} {cy:.6f} {bw:.6f} {bh:.6f}\n")

def main():
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    PROJECT_ROOT = os.path.dirname(BASE_DIR)
    
    IMAGE_DIR = os.path.join(BASE_DIR, "extracted_frames")
    LABEL_DIR = os.path.join(BASE_DIR, "labels")
    
    WEIGHTS_PATH = os.path.join(PROJECT_ROOT, "ai_models", "passenger_counting", "models", "baseline", "weights", "best.pt")
    
    if not os.path.exists(WEIGHTS_PATH):
        print(f"❌ Custom tuned weights not found at {WEIGHTS_PATH}")
        return
        
    print("🧠 Loading tuned YOLOv8s model...")
    model = YOLO(WEIGHTS_PATH)
    
    valid_exts = (".jpg", ".jpeg", ".png", ".bmp")
    all_files = sorted([f for f in os.listdir(IMAGE_DIR) if f.lower().endswith(valid_exts)])
    
    total_images_labeled = 0
    total_detections = 0
    zero_detections = 0
    
    processed_images = []
    
    # ── Auto-labeling Block ──
    for img_file in tqdm(all_files, desc="Auto Labeling", unit="img"):
        img_path = os.path.join(IMAGE_DIR, img_file)
        base_name = os.path.splitext(img_file)[0]
        lbl_path = os.path.join(LABEL_DIR, base_name + ".txt")
        
        # Skip if already labeled (this protects your 50 manual labels from being overwritten)
        if os.path.exists(lbl_path) and os.path.getsize(lbl_path) > 0:
            continue
            
        # NMS threshold=0.35 and confidence=0.70 (Aggressive threshold to natively kill window reflections)
        results = model.predict(img_path, conf=0.70, iou=0.35, verbose=False)
        
        boxes_list = []
        if len(results) > 0 and len(results[0].boxes) > 0:
            boxes_list = results[0].boxes.xywhn.cpu().tolist()
            
        total_images_labeled += 1
        num_dets = len(boxes_list)
        total_detections += num_dets
        if num_dets == 0:
            zero_detections += 1
            
        save_yolo_labels(boxes_list, lbl_path)
        processed_images.append(img_path)
        
    # ── Final Summaries ──
    print("\n✅ Auto-Labeling Finished")
    print(f"Total newly labeled images: {total_images_labeled}")
    if total_images_labeled > 0:
        print(f"Average detections per image: {total_detections / total_images_labeled:.2f}")
    print(f"Images with 0 detections (possible empty bus): {zero_detections}")
    
    # ── Grid Preview Module ──
    if len(processed_images) > 0:
        print("\nGenerating auto_label_preview.png...")
        samples = random.sample(processed_images, min(16, len(processed_images)))
        
        fig, axes = plt.subplots(4, 4, figsize=(16, 16))
        axes = axes.flatten()
        
        for i, ax in enumerate(axes):
            if i < len(samples):
                img_path = samples[i]
                base_name = os.path.splitext(os.path.basename(img_path))[0]
                lbl_path = os.path.join(LABEL_DIR, base_name + ".txt")
                
                img = cv2.imread(img_path)
                if img is not None:
                    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
                    h, w = img.shape[:2]
                    
                    if os.path.exists(lbl_path):
                        with open(lbl_path, "r") as f:
                            for line in f:
                                p = line.strip().split()
                                if len(p) == 5:
                                    cx, cy, bw, bh = [float(x) for x in p[1:]]
                                    x1, y1 = int((cx - bw/2)*w), int((cy - bh/2)*h)
                                    x2, y2 = int((cx + bw/2)*w), int((cy + bh/2)*h)
                                    cv2.rectangle(img, (x1, y1), (x2, y2), (0, 255, 0), 4)
                    
                    ax.imshow(img)
                    ax.axis('off')
            else:
                ax.axis('off')
                
        plt.tight_layout()
        preview_path = os.path.join(BASE_DIR, "auto_label_preview.png")
        plt.savefig(preview_path)
        print(f"Saved random visual grid validation to: {preview_path}")

if __name__ == "__main__":
    main()
