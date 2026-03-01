from ultralytics import YOLO
import torch

def main():
    # ඔයාගේ GPU එක වැඩද කියලා මුලින්ම Check කරමු
    print(f"CUDA Available: {torch.cuda.is_available()}")
    if torch.cuda.is_available():
        print(f"Using GPU: {torch.cuda.get_device_name(0)}")

    # පදනම් මාදිලිය (Pre-trained YOLOv11 Nano model) ලෝඩ් කිරීම
    model = YOLO("yolo11n.pt")

    print("🚀 Starting YOLOv11 Fine-Tuning...")

    # Training ක්‍රියාවලිය
    # data = ඔයාගේ dataset එකේ data.yaml එක තියෙන තැනට path එක දෙන්න
    results = model.train(
        data="dataset/data.yaml",
        epochs=50,                  # මුලින්ම වට 50ක් ට්‍රේන් කරමු
        imgsz=640,                  # පින්තූරවල ප්‍රමාණය
        batch=16,                   # ඔයාගේ 8GB GPU එකට 16ක් ලේසියෙන්ම අදින්න පුළුවන්
        device=0,                   # 0 කියන්නේ GPU එක පාවිච්චි කරන්න කියන එක
        name="bus_passenger_model"  # ට්‍රේන් වුණු මොඩල් එක සේව් වෙන ෆෝල්ඩරයේ නම
    )

    print("✅ Training Completed Successfully!")

if __name__ == '__main__':
    main()