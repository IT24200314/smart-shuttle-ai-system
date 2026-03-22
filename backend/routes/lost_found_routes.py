from fastapi import APIRouter, HTTPException
from utils.firebase_config import db
from models.schemas import ClaimItemRequest, AdminLostFoundActionRequest
from datetime import datetime
import uuid

router = APIRouter()

@router.get("/lost-found/items")
def get_lost_items():
    try:
        docs = db.collection('lost_found_items').where('status', 'in', ['pending', 'found']).get()
        items = []
        for doc in docs:
            data = doc.to_dict()
            data['id'] = doc.id
            items.append(data)
        return {"success": True, "items": items}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/lost-found/claim")
def claim_item(req: ClaimItemRequest):
    try:
        doc_ref = db.collection('lost_found_items').document(req.item_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Item not found")
            
        # Update Item State
        doc_ref.update({
            'status': 'claimRequested',
            'claimedBy': req.student_id
        })
        
        # Log to Audit Request Collection
        req_id = f"CLM-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:4].upper()}"
        db.collection('lost_found_claim_requests').document(req_id).set({
            'item_id': req.item_id,
            'student_id': req.student_id,
            'timestamp': datetime.now().isoformat(),
            'status': 'pending_verification'
        })
        
        return {"success": True, "message": "Claim requested securely"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/lost-found/verify")
def verify_item(req: AdminLostFoundActionRequest):
    try:
        doc_ref = db.collection('lost_found_items').document(req.item_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Item not found")
        
        doc_ref.update({
            'status': 'verified',
            'verifiedBy': req.admin_id,
            'verifiedAt': datetime.now().isoformat()
        })
        return {"success": True, "message": "Item verified successfully"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/lost-found/handover")
def handover_item(req: AdminLostFoundActionRequest):
    try:
        doc_ref = db.collection('lost_found_items').document(req.item_id)
        if not doc_ref.get().exists:
            raise HTTPException(status_code=404, detail="Item not found")
        
        doc_ref.update({
            'status': 'claimed',
            'handedOverBy': req.admin_id,
            'handedOverAt': datetime.now().isoformat()
        })
        return {"success": True, "message": "Item handed over to student"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
