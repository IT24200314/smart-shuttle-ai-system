from ultralytics import YOLO
import torch
import os
import shutil

def main():
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    DATA_YAML = os.path.join(BASE_DIR, "datasets", "fewshot", "data.yaml")
    
    if not os.path.exists(DATA_YAML):
        print(f"❌ Error: {DATA_YAML} not found! Run prepare_fewshot.py first.")
        return
        
    print("🔄 Loading robust YOLOv8s baseline model...")
    model = YOLO('yolov8s.pt')
    
    device = '0' if torch.cuda.is_available() else 'cpu'
    
    PROJECT_DIR = os.path.join(BASE_DIR, "models")
    NAME_DIR = "baseline"
    
    print("⚡ Starting Custom YOLOv8s training (150 epochs)...")
    res = model.train(
        data=DATA_YAML,
        epochs=150,
        imgsz=640,
        batch=8,
        mosaic=1.0,
        fliplr=0.5,        # Adjusted from flipud at user's request (left-right logic)
        degrees=5.0,
        patience=20,
        name=NAME_DIR,
        project=PROJECT_DIR,
        device=device,
        exist_ok=True
    )
    
    # Graph extraction as requested
    results_src = os.path.join(PROJECT_DIR, NAME_DIR, "results.png")
    results_dst = os.path.join(PROJECT_DIR, NAME_DIR, "train_results.png")
    if os.path.exists(results_src):
        shutil.copy2(results_src, results_dst)
        print(f"📊 Saved loss curve graph: {results_dst}")
    
    # Validate and grab mAP50 score
    metrics = model.val() 
    print(f"\n✅ Training Complete! Final mAP50 Score: {metrics.box.map50:.4f}")
    
if __name__ == "__main__":
    main()
