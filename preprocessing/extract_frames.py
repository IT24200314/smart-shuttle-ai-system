import cv2
import os

# Define your paths based on your project structure
VIDEO_DIR = 'raw_videos'
OUTPUT_DIR = 'extracted_frames'

# Extract 1 frame every 5 seconds (assuming 30 FPS video)
# 5 seconds * 30 FPS = 150 frames
FRAME_SKIP = 150 

def extract_frames():
    # Ensure output directory exists
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # Find all MP4 files in the raw_videos folder
    video_files = [f for f in os.listdir(VIDEO_DIR) if f.endswith('.mp4')]
    
    if not video_files:
        print("No MP4 files found in the 'raw_videos' folder.")
        return

    total_extracted = 0

    for video_file in video_files:
        video_path = os.path.join(VIDEO_DIR, video_file)
        print(f"Processing video: {video_file}...")
        
        cap = cv2.VideoCapture(video_path)
        frame_count = 0
        saved_count = 0
        
        while True:
            success, frame = cap.read()
            if not success:
                break # End of video
                
            # Only save the frame if it matches our interval
            if frame_count % FRAME_SKIP == 0:
                # Format: videoName_frameNumber.jpg
                frame_name = f"{video_file.split('.')[0]}_frame_{frame_count}.jpg"
                output_path = os.path.join(OUTPUT_DIR, frame_name)
                
                cv2.imwrite(output_path, frame)
                saved_count += 1
                total_extracted += 1
                
            frame_count += 1
            
        cap.release()
        print(f"  -> Saved {saved_count} frames from {video_file}")

    print(f"\nExtraction Complete! Total frames extracted: {total_extracted}")
    print("Next step: Manually review the 'extracted_frames' folder and delete empty/dark images.")

if __name__ == '__main__':
    extract_frames()
