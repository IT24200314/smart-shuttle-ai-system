import cv2
import os
import numpy as np
import shutil

# Paths
INPUT_DIR = 'extracted_frames'
REJECTED_DIR = 'rejected_frames'

# Thresholds (Oyata mewa wenas karanna puluwan test karala)
BLUR_THRESHOLD = 80.0  # Me ganata wada adu nam blurry kiyala hithanawa
DARK_THRESHOLD = 40.0  # Pixel brightness eka mekata wada adu nam dark kiyala hithanawa

def clean_dataset():
    if not os.path.exists(INPUT_DIR):
        print(f"Error: '{INPUT_DIR}' folder eka hoyaganna ba.")
        return

    # Create a folder for rejected images so we don't delete them permanently right away
    if not os.path.exists(REJECTED_DIR):
        os.makedirs(REJECTED_DIR)

    image_files = [f for f in os.listdir(INPUT_DIR) if f.endswith(('.jpg', '.png'))]
    total_images = len(image_files)
    moved_count = 0

    print(f"Checking {total_images} images for blur and darkness...\n")

    for img_file in image_files:
        img_path = os.path.join(INPUT_DIR, img_file)
        
        # Read image in grayscale (faster for these calculations)
        image = cv2.imread(img_path, cv2.IMREAD_GRAYSCALE)
        
        if image is None:
            continue

        # 1. Check for Blur (Variance of Laplacian)
        blur_value = cv2.Laplacian(image, cv2.CV_64F).var()
        is_blurry = blur_value < BLUR_THRESHOLD

        # 2. Check for Darkness (Average Pixel Brightness)
        brightness_value = np.mean(image)
        is_dark = brightness_value < DARK_THRESHOLD

        if is_blurry or is_dark:
            reason = "Blurry" if is_blurry else "Dark"
            if is_blurry and is_dark:
                reason = "Blurry & Dark"
                
            print(f"Rejecting: {img_file} (Reason: {reason} | Blur: {blur_value:.1f}, Brightness: {brightness_value:.1f})")
            
            # Move the bad image to the rejected folder
            shutil.move(img_path, os.path.join(REJECTED_DIR, img_file))
            moved_count += 1

    print(f"\nCleaning Complete!")
    print(f"Total checked: {total_images}")
    print(f"Good images remaining in '{INPUT_DIR}': {total_images - moved_count}")
    print(f"Bad images moved to '{REJECTED_DIR}': {moved_count}")
    print("\nNext Step: 'rejected_frames' folder eka poddak check karala, eke hoda photos nathnam e folder eka delete karala danna.")

if __name__ == '__main__':
    clean_dataset()