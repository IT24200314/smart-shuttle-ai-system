import os
import shutil
import random
from tqdm import tqdm

def main():
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    PROJECT_ROOT = os.path.dirname(BASE_DIR)
    
    IMG_DIR = os.path.join(BASE_DIR, "extracted_frames")
    LBL_DIR = os.path.join(BASE_DIR, "labels")
    
    DATASET_DIR = os.path.join(PROJECT_ROOT, "ai_models", "passenger_counting", "datasets", "smart_bus_final")
    
    if os.path.exists(DATASET_DIR):
        print("Cleaning previous final_dataset dump...")
        shutil.rmtree(DATASET_DIR)
        
    # Generate identical training structures
    for split in ["train", "val", "test"]:
        os.makedirs(os.path.join(DATASET_DIR, "images", split), exist_ok=True)
        os.makedirs(os.path.join(DATASET_DIR, "labels", split), exist_ok=True)
        
    print("Gathering sequentially generated YOLO payloads...")
    valid_exts = (".jpg", ".jpeg", ".png", ".bmp")
    all_files = os.listdir(IMG_DIR)
    image_files = sorted([f for f in all_files if f.lower().endswith(valid_exts)])
    
    dataset_pairs = []
    for img_name in image_files:
        lbl_name = os.path.splitext(img_name)[0] + ".txt"
        lbl_path = os.path.join(LBL_DIR, lbl_name)
        if os.path.exists(lbl_path):
            dataset_pairs.append((img_name, lbl_name))
            
    print(f"Total cleanly labeled pairs acquired: {len(dataset_pairs)}")
    
    # Shuffle natively to prevent sequence-bias
    random.seed(1337)
    random.shuffle(dataset_pairs)
    
    total = len(dataset_pairs)
    train_end = int(total * 0.70)
    val_end = int(total * 0.90)
    
    def copy_split(start, end, split_dir):
        print(f"Migrating {end - start} files gracefully to -> {split_dir}...")
        for i in tqdm(range(start, end), desc=f"Writing {split_dir}", leave=False):
            img_name, lbl_name = dataset_pairs[i]
            # Copy Image
            shutil.copy2(os.path.join(IMG_DIR, img_name), os.path.join(DATASET_DIR, "images", split_dir, img_name))
            # Copy Txt Bounds
            shutil.copy2(os.path.join(LBL_DIR, lbl_name), os.path.join(DATASET_DIR, "labels", split_dir, lbl_name))
            
    # Deploy segments
    copy_split(0, train_end, "train")
    copy_split(train_end, val_end, "val")
    copy_split(val_end, total, "test")
    
    # Assemble final YOLO hook definition
    yaml_path = os.path.join(DATASET_DIR, "data.yaml")
    with open(yaml_path, "w") as f:
        f.write(f"path: {DATASET_DIR}\n")
        f.write(f"train: images/train\n")
        f.write(f"val: images/val\n")
        f.write(f"test: images/test\n\n")
        f.write(f"nc: 1\n")
        f.write(f"names: ['head']\n")
        
    print(f"✅ Final Production Dataset cleanly locked down at: {DATASET_DIR}")

if __name__ == "__main__":
    main()
