# Lost and Found Fine-Tuning Workflow

## Existing Files Found

- Demo folder: `ai_models/lost_and_found/demo/`
- Demo video: `ai_models/lost_and_found/demo/demo.mp4`
- Demo dataset YAML: `ai_models/lost_and_found/demo/data.yaml`
- Current model: `ai_models/lost_and_found/best (1).pt`
- `best.pt`: not present during analysis. Existing backend logic falls back to `best (1).pt`.
- `ltaa.ai`: not found in `smart-shuttle-ai-system` during analysis, so it cannot be integrated directly.
- Existing Lost and Found inference logic: `ai_models/lost_and_found/demo_inference.py`
- Existing general labeling helpers: `preprocessing/extract_frames.py`, `preprocessing/auto_label.py`, `preprocessing/label_reviewer.py`

The current model loads successfully with Ultralytics YOLO and has these classes:

```text
0 Bag
1 Bottle
2 Laptop
3 Umbrella
```

## Workspace

Temporary work is kept under:

```text
ai_models/lost_and_found/fine_tune_workspace/
```

Important subfolders:

- `extracted_frames/`
- `auto_labels/`
- `reviewed_dataset/`
- `images/train/`
- `images/val/`
- `labels/train/`
- `labels/val/`
- `runs/`
- `scripts/`
- `data.yaml`

## Commands

Run these commands from:

```text
ai_models/lost_and_found/fine_tune_workspace/
```

Extract 40-50 evenly spaced frames from the demo video, and copy any demo images if present:

```powershell
python scripts/extract_frames.py
```

Auto-label extracted frames with the existing YOLO model:

```powershell
python scripts/auto_label.py
```

Review and correct labels before training:

```powershell
python scripts/review_and_edit_labels.py
```

Optional manual text-editing mode:

```powershell
python scripts/review_and_edit_labels.py --manual-text-editor
```

Split reviewed labels into train and validation sets:

```powershell
python scripts/split_dataset.py
```

Fine-tune only after reviewing labels. This script refuses to train without explicit confirmation:

```powershell
python scripts/finetune_bestpt.py --i-reviewed-labels
```

Verify the final promoted model:

```powershell
python scripts/verify_final_model.py
```

Delete temporary workspace files only after final verification succeeds:

```powershell
python scripts/cleanup_temp_files.py --confirmed-final-verified
```

## Safety Rules

- Do not train on unreviewed auto-labels.
- `finetune_bestpt.py` requires `--i-reviewed-labels`.
- The original model is backed up to `ai_models/lost_and_found/model_backup/original_best.pt` before promotion.
- The improved model is copied to:
  - `ai_models/lost_and_found/best.pt`
  - `ai_models/lost_and_found/final_best_finetuned.pt`
- Cleanup refuses to run unless `best.pt`, `final_best_finetuned.pt`, and `model_backup/original_best.pt` all exist and `best.pt` can load.
- Cleanup does not delete:
  - `demo/`
  - `ltaa.ai` if it is later added
  - `model_backup/original_best.pt`
  - `best.pt`
  - `final_best_finetuned.pt`

## Label Review Warning

Auto-labels are only a starting point. They can contain missed objects, wrong boxes, wrong classes, and false positives. Review and correct every label before real training.
