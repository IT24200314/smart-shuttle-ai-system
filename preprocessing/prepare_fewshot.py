import os
import shutil
import yaml

def main():
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    PROJECT_ROOT = os.path.dirname(BASE_DIR)
    
    SOURCE_IMAGES = os.path.join(BASE_DIR, "extracted_frames")
    SOURCE_LABELS = os.path.join(BASE_DIR, "labels")
    
    DATASET_DIR = os.path.join(PROJECT_ROOT, "ai_models", "passenger_counting", "datasets", "fewshot")
    
    if os.path.exists(DATASET_DIR):
        print(f"🔄 Cleaning existing dataset structure at: {DATASET_DIR}")
        shutil.rmtree(DATASET_DIR)
        
    for split in ["train", "val"]:
        os.makedirs(os.path.join(DATASET_DIR, "images", split), exist_ok=True)
        os.makedirs(os.path.join(DATASET_DIR, "labels", split), exist_ok=True)
        
    print("🔎 Searching for exactly 50 manually formatted YOLO frames...")
    
    valid_exts = (".jpg", ".jpeg", ".png", ".bmp")
    all_files = os.listdir(SOURCE_IMAGES)
    image_files = sorted([f for f in all_files if f.lower().endswith(valid_exts)])
    
    labeled_files = []
    # Identify images that have an actual corresponding txt label file
    for img_name in image_files:
        lbl_name = os.path.splitext(img_name)[0] + ".txt"
        lbl_path = os.path.join(SOURCE_LABELS, lbl_name)
        if os.path.exists(lbl_path):
            labeled_files.append((img_name, lbl_name))
            if len(labeled_files) == 50:
                break
                
    if len(labeled_files) < 50:
        print(f"⚠️ Warning: Found only {len(labeled_files)} out of 50 requested label pairings.")
    
    # Split: 40 train, 10 val
    train_count = min(40, int(len(labeled_files) * 0.8))
    
    for i, (img_name, lbl_name) in enumerate(labeled_files):
        split = "train" if i < train_count else "val"
        
        src_img = os.path.join(SOURCE_IMAGES, img_name)
        src_lbl = os.path.join(SOURCE_LABELS, lbl_name)
        
        dst_img = os.path.join(DATASET_DIR, "images", split, img_name)
        dst_lbl = os.path.join(DATASET_DIR, "labels", split, lbl_name)
        
        shutil.copy2(src_img, dst_img)
        shutil.copy2(src_lbl, dst_lbl)
                
    print(f"\n📊 Summary:\n  - Training images: {train_count}\n  - Validation images: {len(labeled_files) - train_count}")
    
    yaml_path = os.path.join(DATASET_DIR, "data.yaml")
    
    with open(yaml_path, "w") as f:
        f.write(f"path: {DATASET_DIR}\n")
        f.write(f"train: images/train\n")
        f.write(f"val: images/val\n\n")
        f.write(f"nc: 1\n")
        f.write(f"names: ['head']\n")
        
    print(f"✅ Data.yaml cleanly output at: {yaml_path}")
    print("✨ Dataset isolated perfectly!")

if __name__ == "__main__":
    main()
