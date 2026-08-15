from datetime import datetime, timezone
from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
from services.firebase_service import get_db
from services.pregnancy_service import (
    get_active_pregnancy,
    get_active_or_legacy,
    compute_pregnancy_week,
)

journal_bp = Blueprint("journal", __name__)


def _serialize_entry(doc, doc_id):
    e = doc.to_dict() if hasattr(doc, "to_dict") else doc
    ts = e.get("created_at")
    return {
        "id": e.get("id", doc_id),
        "text": e.get("text", ""),
        "feeling": e.get("feeling", ""),
        "photos": e.get("photos", []),
        "week": e.get("week", 0),
        "doctor_name": e.get("doctor_name", ""),
        "date": e.get("date", ""),
        "created_at": ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else "",
    }


@journal_bp.route("/journal/create", methods=["POST"])
def create_entry():
    try:
        data = request.get_json() or {}
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        # Semaine de grossesse au moment de l'écriture
        _, preg_data, _ = get_active_or_legacy(db, phone)
        week = compute_pregnancy_week(preg_data) if preg_data else 0

        doctor_phone = ""
        doctor_name = ""
        if preg_data:
            doctor_phone = preg_data.get("doctor_phone", "")
            doctor_name = preg_data.get("doctor_name", "")
        if not doctor_phone:
            links = (
                db.collection("patient_links")
                .where("patient_phone", "==", phone)
                .limit(1)
                .stream()
            )
            for link in links:
                d = link.to_dict()
                doctor_phone = d.get("doctor_phone", "")
                doctor_name = d.get("doctor_name", "")

        now = datetime.now(timezone.utc)
        entry_ref = db.collection("users").document(phone).collection("journal").document()
        entry_ref.set({
            "id": entry_ref.id,
            "phone": phone,
            "text": (data.get("text") or "").strip(),
            "feeling": data.get("feeling", ""),
            "photos": [p for p in (data.get("photos") or []) if isinstance(p, str)],
            "week": week,
            "doctor_phone": doctor_phone,
            "doctor_name": doctor_name,
            "date": now.strftime("%Y-%m-%d"),
            "created_at": firestore.SERVER_TIMESTAMP,
        })

        return jsonify({"succes": True, "journal_id": entry_ref.id}), 200

    except Exception as e:
        current_app.logger.error(f"Journal create error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@journal_bp.route("/journal/list", methods=["POST"])
def list_entries():
    try:
        data = request.get_json() or {}
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        docs = (
            db.collection("users").document(phone)
            .collection("journal")
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(200)
            .get()
        )

        entries = [_serialize_entry(doc, doc.id) for doc in docs]

        return jsonify({"succes": True, "entries": entries, "count": len(entries)}), 200

    except Exception as e:
        current_app.logger.error(f"Journal list error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@journal_bp.route("/journal/delete", methods=["POST"])
def delete_entry():
    try:
        data = request.get_json() or {}
        phone = data.get("phone")
        journal_id = data.get("journal_id")
        if not phone or not journal_id:
            return jsonify({"succes": False, "erreur": "phone et journal_id requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        db.collection("users").document(phone).collection("journal").document(journal_id).delete()

        return jsonify({"succes": True}), 200

    except Exception as e:
        current_app.logger.error(f"Journal delete error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@journal_bp.route("/doctor/patient-journal", methods=["POST"])
def doctor_patient_journal():
    try:
        data = request.get_json() or {}
        doctor_phone = data.get("doctor_phone")
        patient_phone = data.get("patient_phone")
        if not doctor_phone or not patient_phone:
            return jsonify({"succes": False, "erreur": "doctor_phone et patient_phone requis"}), 400

        db = get_db()
        if not db:
            return jsonify({"succes": False, "erreur": "Firebase non configuré"}), 500

        # Confidentialité : seul le médecin lié peut lire
        authorized = False
        doctor_docs = list(db.collection("doctors").where("phone", "==", doctor_phone).limit(1).stream())
        if doctor_docs:
            doctor_id = doctor_docs[0].id
            links = (
                db.collection("patient_links")
                .where("doctor_id", "==", doctor_id)
                .where("patient_phone", "==", patient_phone)
                .limit(1)
                .stream()
            )
            if any(True for _ in links):
                authorized = True

        if not authorized:
            _, preg_data = get_active_pregnancy(db, patient_phone)
            if preg_data and preg_data.get("doctor_phone") == doctor_phone:
                authorized = True

        if not authorized:
            return jsonify({
                "succes": False,
                "erreur": "Accès refusé : ce médecin n'est pas lié à cette patiente",
            }), 403

        docs = (
            db.collection("users").document(patient_phone)
            .collection("journal")
            .order_by("created_at", direction=firestore.Query.DESCENDING)
            .limit(200)
            .get()
        )

        entries = [_serialize_entry(doc, doc.id) for doc in docs]

        return jsonify({"succes": True, "entries": entries, "count": len(entries)}), 200

    except Exception as e:
        current_app.logger.error(f"Doctor patient journal error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500