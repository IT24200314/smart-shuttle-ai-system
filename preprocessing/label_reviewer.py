import cv2
import os
import glob
import math

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
IMAGE_DIR = os.path.join(BASE_DIR, "extracted_frames")
LABEL_DIR = os.path.join(BASE_DIR, "labels")

os.makedirs(IMAGE_DIR, exist_ok=True)
os.makedirs(LABEL_DIR, exist_ok=True)

class LabelReviewer:
    def __init__(self):
        valid_exts = (".jpg", ".jpeg", ".png")
        import random
        # Sort first for determinism, then shuffle with a locked seed so the order never changes across reboots
        sorted_images = sorted([f for f in os.listdir(IMAGE_DIR) if f.lower().endswith(valid_exts)])
        random.seed(42)
        random.shuffle(sorted_images)
        self.images = sorted_images
        if not self.images:
            print("❌ No images found in extracted_frames/")
            exit(1)
            
        self.idx = 0
        self.target_limit = 5000  # Vastly expanded dynamically!
        
        self.boxes = []
        self.drawing = False
        self.ix, self.iy = -1, -1
        self.temp_box = None
        self.img_h, self.img_w = 1, 1
        self.current_img = None
        self.display_img = None
        self.window_name = "Label Reviewer - Press S (Save), D (Skip), A (Prev), Q (Quit)"
        
        cv2.namedWindow(self.window_name, cv2.WINDOW_NORMAL)
        cv2.setMouseCallback(self.window_name, self.mouse_callback)

    def count_labeled(self):
        return len([f for f in os.listdir(LABEL_DIR) if f.endswith('.txt') and os.path.getsize(os.path.join(LABEL_DIR, f)) > 0])

    def load_labels(self):
        self.boxes = []
        lbl_path = os.path.join(LABEL_DIR, os.path.splitext(self.images[self.idx])[0] + ".txt")
        if os.path.exists(lbl_path) and os.path.getsize(lbl_path) > 0:
            with open(lbl_path, "r") as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) == 5:
                        self.boxes.append([float(x) for x in parts[1:]])

    def save_labels(self):
        lbl_path = os.path.join(LABEL_DIR, os.path.splitext(self.images[self.idx])[0] + ".txt")
        with open(lbl_path, "w") as f:
            for b in self.boxes:
                # b is [cx, cy, w, h] normalized
                f.write(f"0 {b[0]:.6f} {b[1]:.6f} {b[2]:.6f} {b[3]:.6f}\n")

    def skip_labels(self):
        # Creates an empty label file to denote a skipped/empty frame
        lbl_path = os.path.join(LABEL_DIR, os.path.splitext(self.images[self.idx])[0] + ".txt")
        # Just clear boxes and save empty file
        self.boxes = []
        with open(lbl_path, "w") as f:
             pass

    def draw_screen(self):
        self.display_img = self.current_img.copy()
        
        # Draw confirmed boxes
        for b in self.boxes:
            cx, cy, bw, bh = b
            x1 = int((cx - bw/2) * self.img_w)
            y1 = int((cy - bh/2) * self.img_h)
            x2 = int((cx + bw/2) * self.img_w)
            y2 = int((cy + bh/2) * self.img_h)
            cv2.rectangle(self.display_img, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(self.display_img, "head", (x1, max(y1-5, 10)), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

        # Draw actively drawing box
        if self.temp_box is not None:
            x1, y1, x2, y2 = self.temp_box
            cv2.rectangle(self.display_img, (x1, y1), (x2, y2), (0, 165, 255), 2)
            
        progress_text = f"Image {self.idx + 1} / {len(self.images)} | Labeled Target: {self.count_labeled()} / {self.target_limit}"
        cv2.putText(self.display_img, progress_text, (20, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 4)
        cv2.putText(self.display_img, progress_text, (20, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 0), 2)
            
        cv2.imshow(self.window_name, self.display_img)

    def mouse_callback(self, event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            self.drawing = True
            self.ix, self.iy = x, y
            self.temp_box = (x, y, x, y)
        elif event == cv2.EVENT_MOUSEMOVE:
            if self.drawing:
                self.temp_box = (self.ix, self.iy, x, y)
                self.draw_screen()
        elif event == cv2.EVENT_LBUTTONUP:
            if self.drawing:
                self.drawing = False
                x1, y1, x2, y2 = min(self.ix, x), min(self.iy, y), max(self.ix, x), max(self.iy, y)
                self.temp_box = None
                if (x2 - x1) > 5 and (y2 - y1) > 5:
                    # Convert to cx, cy, w, h
                    cx = ((x1 + x2) / 2) / self.img_w
                    cy = ((y1 + y2) / 2) / self.img_h
                    bw = (x2 - x1) / self.img_w
                    bh = (y2 - y1) / self.img_h
                    self.boxes.append([cx, cy, bw, bh])
                self.draw_screen()
        elif event == cv2.EVENT_RBUTTONDOWN:
            # Delete nearest box
            if self.boxes:
                min_dist = float('inf')
                min_idx = -1
                for i, b in enumerate(self.boxes):
                    bcx = b[0] * self.img_w
                    bcy = b[1] * self.img_h
                    dist = math.hypot(bcx - x, bcy - y)
                    if dist < min_dist:
                        min_dist = dist
                        min_idx = i
                if min_idx != -1:
                    del self.boxes[min_idx]
                    self.draw_screen()

    def run(self):
        while self.idx < len(self.images):
            img_path = os.path.join(IMAGE_DIR, self.images[self.idx])
            self.current_img = cv2.imread(img_path)
            if self.current_img is None:
                self.idx += 1
                continue
                
            self.img_h, self.img_w = self.current_img.shape[:2]
            self.load_labels()
            self.draw_screen()
            
            while True:
                key = cv2.waitKey(10) & 0xFF
                if key == ord('s'):
                    self.save_labels()
                    self.idx += 1
                    break
                elif key == ord('d'):
                    self.skip_labels()
                    self.idx += 1
                    break
                elif key == ord('a'):
                    if self.idx > 0:
                        self.idx -= 1
                        break
                elif key == ord('q'):
                    cv2.destroyAllWindows()
                    return

        cv2.destroyAllWindows()

if __name__ == "__main__":
    app = LabelReviewer()
    app.run()
