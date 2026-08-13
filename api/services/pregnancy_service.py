from datetime import datetime, timezone, timedelta
from firebase_admin import firestore


def _now():
    return datetime.now(timezone.utc)


def get_active_pregnancy(db, phone):
    """Get the active pregnancy for a user. Returns (pregnancy_id, pregnancy_data) or (None, None)."""
    user_doc = db.collection("users").document(phone).get()
    if not user_doc.exists:
        return None, None
    user_data = user_doc.to_dict()
    active_id = user_data.get("active_pregnancy_id")
    if not active_id:
        return None, None
    preg_doc = db.collection("users").document(phone).collection("pregnancies").document(active_id).get()
    if not preg_doc.exists:
        return None, None
    return active_id, preg_doc.to_dict()


def get_active_or_legacy(db, phone):
    """Get active pregnancy data, or legacy flat data for backward compat.

    Returns (pregnancy_id, pregnancy_data, is_pregnancy).
    is_pregnancy=True means data came from a pregnancy doc.
    is_pregnancy=False means data came from legacy flat fields.
    """
    user_doc = db.collection("users").document(phone).get()
    if not user_doc.exists:
        return None, None, False
    user_data = user_doc.to_dict()
    active_id = user_data.get("active_pregnancy_id")
    if active_id:
        preg_doc = db.collection("users").document(phone).collection("pregnancies").document(active_id).get()
        if preg_doc.exists:
            return active_id, preg_doc.to_dict(), True
    # Legacy fallback
    return None, user_data, False


def get_pregnancy_path(db, phone, pregnancy_id):
    """Get Firestore reference for a pregnancy's subcollections."""
    return db.collection("users").document(phone).collection("pregnancies").document(pregnancy_id)


def create_pregnancy(db, phone, data):
    """Create a new pregnancy and set it as active for the user."""
    preg_id = db.collection("users").document(phone).collection("pregnancies").document().id

    preg_data = {
        "id": preg_id,
        "status": "active",
        "created_at": firestore.SERVER_TIMESTAMP,
        "pregnancy_method": data.get("pregnancy_method", ""),
        "lmp_date": data.get("lmp_date", ""),
        "manual_week": int(data.get("manual_week", 0)) if data.get("manual_week") else 0,
        "reference_date": data.get("reference_date", ""),
        "due_date": data.get("due_date", ""),
        "doctor_phone": data.get("doctor_phone", ""),
        "doctor_name": data.get("doctor_name", ""),
        "doctor_specialty": data.get("doctor_specialty", ""),
    }

    if preg_data["pregnancy_method"] == "lmp" and preg_data.get("lmp_date"):
        try:
            lmp_dt = datetime.strptime(preg_data["lmp_date"], "%Y-%m-%d")
            due = lmp_dt + timedelta(days=280)
            preg_data["due_date"] = due.strftime("%Y-%m-%d")
            diff = (_now() - lmp_dt.replace(tzinfo=timezone.utc)).days
            preg_data["manual_week"] = max(0, diff // 7)
        except (ValueError, TypeError):
            pass

    db.collection("users").document(phone).collection("pregnancies").document(preg_id).set(preg_data)

    db.collection("users").document(phone).set({
        "active_pregnancy_id": preg_id,
    }, merge=True)

    return preg_id


def finish_pregnancy(db, phone, pregnancy_id, birth_date):
    """Mark a pregnancy as completed with the actual birth date."""
    preg_ref = db.collection("users").document(phone).collection("pregnancies").document(pregnancy_id)
    preg_ref.update({
        "status": "completed",
        "actual_birth_date": birth_date,
        "completed_at": firestore.SERVER_TIMESTAMP,
    })

    db.collection("users").document(phone).update({
        "active_pregnancy_id": firestore.DELETE_FIELD,
    })


def get_all_pregnancies(db, phone):
    """Get all pregnancies for a user, sorted by creation date desc."""
    docs = (
        db.collection("users").document(phone)
        .collection("pregnancies")
        .order_by("created_at", direction=firestore.Query.DESCENDING)
        .get()
    )
    pregnancies = []
    for doc in docs:
        d = doc.to_dict()
        ts = d.get("created_at")
        d["created_at"] = ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else ""
        pregnancies.append(d)
    return pregnancies


def compute_pregnancy_week(data):
    """Compute current pregnancy week from stored pregnancy data."""
    if data.get("status") == "completed":
        return 0
    method = data.get("pregnancy_method", "")
    if method == "lmp":
        lmp_str = data.get("lmp_date", "")
        if lmp_str:
            try:
                lmp = datetime.strptime(lmp_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
                diff = (_now() - lmp).days
                return max(0, diff // 7)
            except (ValueError, TypeError):
                pass
    elif method == "manual":
        ref_str = data.get("reference_date", "")
        mw = data.get("manual_week", 0)
        if ref_str and mw:
            try:
                ref = datetime.strptime(ref_str, "%Y-%m-%d").replace(tzinfo=timezone.utc)
                diff = (_now() - ref).days
                return max(0, int(mw) + diff // 7)
            except (ValueError, TypeError):
                pass
    return data.get("pregnancy_week", 0) if not isinstance(data.get("pregnancy_week"), str) else 0
