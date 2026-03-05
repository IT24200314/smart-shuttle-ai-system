from ultralytics import YOLO
import torch

def main():
    # Let's first check if your GPU is working
    print(f"CUDA Available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        device = 0
        print(f"Using GPU: {torch.cuda.get_device_name(0)}")
    else:
        device = "cpu"
        print("Using CPU as GPU is not available.")

    # Loading the base model (Pre-trained YOLOv11 Nano model)
    model = YOLO("yolo11n.pt")

    print("🚀 Starting YOLOv11 Fine-Tuning...")

    # Training process
    try:
        # data = Give the path to your dataset's data.yaml file
        results = model.train(
            data="dataset/data.yaml",
            epochs=50,                  # Let's train for 50 epochs first
            imgsz=640,                  # Image size
            batch=16,                   # Your 8GB GPU can easily handle a batch size of 16
            device=device,              # 0 means to use the GPU
            name="bus_passenger_model"  # Name of the folder where the trained model will be saved
        )

        print("✅ Training Completed Successfully!")
    except Exception as e:
        print(f"❌ An error occurred during training: {e}")
        print("💡 Hint: Please check if dataset paths in 'data.yaml' are correct and all dependencies are installed.")

if __name__ == '__main__':
    main()