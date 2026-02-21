import cv2
from ultralytics import YOLO
import os

# Get the directory of the current script
script_dir = os.path.dirname(os.path.abspath(__file__))
model_path = os.path.join(script_dir, 'yolov8n.pt')
output_video_path = os.path.join(script_dir, 'passenger_counting_output.avi')

# 1. YOLOv8 Model එක load කිරීම
model = YOLO(model_path) 

# 2. Webcam එක පාවිච්චි කිරීම
cap = cv2.VideoCapture(0) 

# Define the video writer
# Get frame properties from the capture
frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
fps = int(cap.get(cv2.CAP_PROP_FPS))
if fps == 0: # Set a default FPS if it cannot be determined from webcam
    fps = 20

# Define the codec and create VideoWriter object
fourcc = cv2.VideoWriter_fourcc(*'XVID')
out = cv2.VideoWriter(output_video_path, fourcc, fps, (frame_width, frame_height))

print("Processing video... Press Ctrl+C in the terminal to stop.")

try:
    while cap.isOpened():
        success, frame = cap.read()
        if not success:
            break

        # 3. AI මගින් මිනිසුන් හඳුනා ගැනීම (Class 0 = Person)
        results = model(frame, classes=[0], conf=0.5)

        # 4. හඳුනාගත් සංඛ්‍යාව ගණනය කිරීම
        passenger_count = len(results[0].boxes)
        
        # 5. ප්‍රතිඵලය Frame එක මත ඇඳීම
        annotated_frame = results[0].plot()
        cv2.putText(annotated_frame, f"Live Passengers: {passenger_count}", (50, 50), 
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

        # 6. ප්‍රතිඵලය video file එකට ලිවීම
        out.write(annotated_frame)

except KeyboardInterrupt:
    # Allow stopping the script with Ctrl+C
    print("Stopping and saving video...")

# Release everything when the job is finished
cap.release()
out.release()
cv2.destroyAllWindows()

print(f"Video processing complete. Output saved to: {output_video_path}")
