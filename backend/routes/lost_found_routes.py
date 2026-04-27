from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Body, HTTPException

from utils.firebase_config import db


router = APIRouter()

ACTIVE_CLAIM_STATUSES = {"pending", "pending_verification", "approved"}


def _now_iso() -> str:
    return datetime.now().isoformat()


def _doc_with_id(snapshot) -> dict[str, Any]:
    data = snapshot.to_dict() or {}
    doc_id = snapshot.id
    data.setdefault("id", doc_id)
    data.setdefault("itemId", data.get("item_id", doc_id))
    data.setdefault("item_id", data.get("itemId", doc_id))
    data.setdefault("itemName", data.get("name", "Item"))
    data.setdefault("name", data.get("itemName", data.get("type", "Item")))
    data.setdefault("itemType", data.get("type", data.get("itemName", "item")))
    data.setdefault("type", data.get("itemType", "item"))
    data.setdefault("description", data.get("notes", "Found on bus"))
    data.setdefault("detectedAt", data.get("createdAt", data.get("date_found")))
    data.setdefault("foundedAt", data.get("date_found", data.get("detectedAt")))
    data.setdefault("status", "available")
    return data


def _claim_with_id(snapshot) -> dict[str, Any]:
    data = snapshot.to_dict() or {}
    claim_id = snapshot.id
    data.setdefault("id", claim_id)
    data.setdefault("claimId", data.get("claim_id", claim_id))
    data.setdefault("claim_id", data.get("claimId", claim_id))
    data.setdefault("itemId", data.get("item_id"))
    data.setdefault("item_id", data.get("itemId"))
    data.setdefault("studentId", data.get("student_id"))
    data.setdefault("student_id", data.get("studentId"))
    data.setdefault("studentName", data.get("student_name", "Student"))
    data.setdefault("studentEmail", data.get("student_email", data.get("studentId")))
    data.setdefault("message", data.get("reason", "Claim request"))
    data.setdefault("reason", data.get("message", "Claim request"))
    data.setdefault("requestedAt", data.get("timestamp", data.get("createdAt")))
    data.setdefault("updatedAt", data.get("updated_at", data.get("requestedAt")))
    data.setdefault("adminNote", data.get("admin_note"))
    data.setdefault("status", "pending")
    return data


def _item_ref(item_id: str):
    return db.collection("lost_found_items").document(item_id)


def _claim_ref(claim_id: str):
    return db.collection("lost_found_claim_requests").document(claim_id)


def _get_item_or_404(item_id: str):
    snapshot = _item_ref(item_id).get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Item not found")
    return snapshot


def _generate_claim_id() -> str:
    return f"CLM-{datetime.now().strftime('%Y%m%d%H%M%S')}-{uuid.uuid4().hex[:4].upper()}"


def _active_claim_for_student(item_id: str, student_id: str) -> dict[str, Any] | None:
    docs = db.collection("lost_found_claim_requests").where("itemId", "==", item_id).get()
    for doc in docs:
        data = _claim_with_id(doc)
        if (
            str(data.get("studentId") or data.get("student_id") or "") == student_id
            and str(data.get("status") or "").lower() in ACTIVE_CLAIM_STATUSES
        ):
            return data
    return None


def _list_items(*, only_available: bool = False) -> list[dict[str, Any]]:
    docs = db.collection("lost_found_items").limit(100).get()
    items = [_doc_with_id(doc) for doc in docs]
    if only_available:
        items = [
            item
            for item in items
            if str(item.get("status") or "").lower() == "available"
        ]
    return sorted(
        items,
        key=lambda item: str(item.get("detectedAt") or item.get("createdAt") or ""),
        reverse=True,
    )


@router.get("/lost-found/items")
def get_lost_items():
    try:
        return {"success": True, "items": _list_items()}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.get("/lost-found/items/available")
def get_available_lost_items():
    try:
        return {"success": True, "items": _list_items(only_available=True)}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/lost-found/items/{item_id}/claim")
def claim_item_by_id(item_id: str, payload: dict[str, Any] = Body(default_factory=dict)):
    try:
        item_snapshot = _get_item_or_404(item_id)
        item = _doc_with_id(item_snapshot)
        student_id = str(
            payload.get("studentId") or payload.get("student_id") or payload.get("email") or ""
        ).strip()
        if not student_id:
            raise HTTPException(status_code=400, detail="studentId is required")

        existing = _active_claim_for_student(item_id, student_id)
        if existing:
            return {
                "success": True,
                "message": "You already have an active claim for this item",
                "claim": existing,
            }

        status = str(item.get("status") or "available").lower()
        if status not in {"available", "found", "pending"}:
            raise HTTPException(status_code=400, detail="Item is not available for claim")

        now = _now_iso()
        claim_id = _generate_claim_id()
        student_name = str(payload.get("studentName") or payload.get("student_name") or "Student")
        student_email = str(payload.get("studentEmail") or payload.get("student_email") or student_id)
        message = str(payload.get("message") or payload.get("reason") or "Claim request")
        claim_payload = {
            "claimId": claim_id,
            "claim_id": claim_id,
            "itemId": item_id,
            "item_id": item_id,
            "itemName": item.get("itemName") or item.get("name"),
            "studentId": student_id,
            "student_id": student_id,
            "studentName": student_name,
            "student_name": student_name,
            "studentEmail": student_email,
            "student_email": student_email,
            "reason": message,
            "message": message,
            "status": "pending",
            "requestedAt": now,
            "timestamp": now,
            "createdAt": now,
            "updatedAt": now,
            "updated_at": now,
            "adminNote": None,
            "admin_note": None,
        }
        _claim_ref(claim_id).set(claim_payload)
        _item_ref(item_id).set(
            {
                "status": "claim_requested",
                "claimedBy": student_id,
                "claimRequestId": claim_id,
                "updatedAt": now,
                "updated_at": now,
            },
            merge=True,
        )
        return {
            "success": True,
            "message": "Claim request sent to admin",
            "claim": claim_payload,
        }
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/lost-found/claim")
def claim_item_legacy(payload: dict[str, Any] = Body(default_factory=dict)):
    item_id = str(payload.get("item_id") or payload.get("itemId") or "").strip()
    if not item_id:
        raise HTTPException(status_code=400, detail="item_id is required")
    return claim_item_by_id(item_id, payload)


@router.get("/lost-found/claims")
def get_claims():
    try:
        docs = db.collection("lost_found_claim_requests").limit(100).get()
        claims = sorted(
            [_claim_with_id(doc) for doc in docs],
            key=lambda claim: str(claim.get("requestedAt") or ""),
            reverse=True,
        )
        return {"success": True, "claims": claims}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


def _update_claim_status(claim_id: str, status: str, payload: dict[str, Any]) -> dict[str, Any]:
    snapshot = _claim_ref(claim_id).get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="Claim request not found")

    claim = _claim_with_id(snapshot)
    item_id = str(claim.get("itemId") or claim.get("item_id") or "")
    item_exists = False
    if item_id:
        item_exists = _item_ref(item_id).get().exists

    now = _now_iso()
    admin_note = payload.get("adminNote") or payload.get("admin_note")
    claim_update = {
        "status": status,
        "updatedAt": now,
        "updated_at": now,
    }
    if admin_note is not None:
        claim_update["adminNote"] = str(admin_note)
        claim_update["admin_note"] = str(admin_note)

    _claim_ref(claim_id).set(claim_update, merge=True)

    item_update: dict[str, Any] = {"updatedAt": now, "updated_at": now}
    if status == "approved":
        item_update.update(
            {
                "status": "approved",
                "claimedBy": claim.get("studentId"),
                "claimRequestId": claim_id,
            }
        )
    elif status in {"rejected", "cancelled"}:
        item_update.update(
            {
                "status": "available",
                "claimedBy": None,
                "claimRequestId": None,
            }
        )
    elif status == "collected":
        item_update.update(
            {
                "status": "collected",
                "claimedBy": claim.get("studentId"),
                "claimRequestId": claim_id,
                "collectedAt": now,
            }
        )

    if item_id and item_exists:
        _item_ref(item_id).set(item_update, merge=True)

    updated_claim = {**claim, **claim_update}
    return {"success": True, "claim": updated_claim}


@router.post("/lost-found/claims/{claim_id}/approve")
def approve_claim(claim_id: str, payload: dict[str, Any] = Body(default_factory=dict)):
    return _update_claim_status(claim_id, "approved", payload)


@router.post("/lost-found/claims/{claim_id}/reject")
def reject_claim(claim_id: str, payload: dict[str, Any] = Body(default_factory=dict)):
    return _update_claim_status(claim_id, "rejected", payload)


@router.post("/lost-found/claims/{claim_id}/cancel")
def cancel_claim(claim_id: str, payload: dict[str, Any] = Body(default_factory=dict)):
    return _update_claim_status(claim_id, "cancelled", payload)


@router.post("/lost-found/items/{item_id}/mark-collected")
def mark_item_collected(item_id: str, payload: dict[str, Any] = Body(default_factory=dict)):
    try:
        item = _doc_with_id(_get_item_or_404(item_id))
        claim_id = str(payload.get("claimId") or payload.get("claim_id") or item.get("claimRequestId") or "")
        if claim_id:
            return _update_claim_status(claim_id, "collected", payload)

        now = _now_iso()
        _item_ref(item_id).set(
            {
                "status": "collected",
                "updatedAt": now,
                "updated_at": now,
                "collectedAt": now,
            },
            merge=True,
        )
        return {"success": True, "itemId": item_id, "status": "collected"}
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@router.post("/lost-found/verify")
def verify_item_legacy(payload: dict[str, Any] = Body(default_factory=dict)):
    claim_id = str(payload.get("claim_id") or payload.get("claimId") or "").strip()
    if claim_id:
        return approve_claim(claim_id, payload)

    item_id = str(payload.get("item_id") or payload.get("itemId") or "").strip()
    if not item_id:
        raise HTTPException(status_code=400, detail="item_id is required")
    item = _doc_with_id(_get_item_or_404(item_id))
    linked_claim = str(item.get("claimRequestId") or "")
    if linked_claim:
        return approve_claim(linked_claim, payload)
    now = _now_iso()
    _item_ref(item_id).set({"status": "approved", "updatedAt": now}, merge=True)
    return {"success": True, "message": "Item approved"}


@router.post("/lost-found/handover")
def handover_item_legacy(payload: dict[str, Any] = Body(default_factory=dict)):
    item_id = str(payload.get("item_id") or payload.get("itemId") or "").strip()
    if not item_id:
        raise HTTPException(status_code=400, detail="item_id is required")
    return mark_item_collected(item_id, payload)
