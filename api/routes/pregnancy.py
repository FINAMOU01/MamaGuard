from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
from services.firebase_service import get_db
from services.pregnancy_service import (
    get_active_pregnancy,
    create_pregnancy,
    finish_pregnancy,
    get_all_pregnancies,
    compute_pregnancy_week,
)

pregnancy_bp = Blueprint("pregnancy", __name__)


@pregnancy_bp.route("/pregnancy/active", methods=["POST"])
def active_pregnancy():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        preg_id, preg_data = get_active_pregnancy(db, phone)
        if not preg_id:
            return jsonify({"succes": False, "has_active": False}), 200

        week = compute_pregnancy_week(preg_data)
        return jsonify({
            "succes": True,
            "has_active": True,
            "pregnancy": {
                "id": preg_id,
                "status": preg_data.get("status", "active"),
                "pregnancy_method": preg_data.get("pregnancy_method", ""),
                "lmp_date": preg_data.get("lmp_date", ""),
                "manual_week": preg_data.get("manual_week", 0),
                "reference_date": preg_data.get("reference_date", ""),
                "due_date": preg_data.get("due_date", ""),
                "current_week": week,
                "doctor_phone": preg_data.get("doctor_phone", ""),
                "doctor_name": preg_data.get("doctor_name", ""),
                "doctor_specialty": preg_data.get("doctor_specialty", ""),
                "actual_birth_date": preg_data.get("actual_birth_date", ""),
                "created_at": preg_data.get("created_at", ""),
            }
        }), 200

    except Exception as e:
        current_app.logger.error(f"Active pregnancy error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@pregnancy_bp.route("/pregnancy/create", methods=["POST"])
def new_pregnancy():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()

        # Check no active pregnancy
        active_id, _ = get_active_pregnancy(db, phone)
        if active_id:
            return jsonify({"succes": False, "erreur": "Une grossesse est déjà active. Terminez-la d'abord."}), 400

        preg_id = create_pregnancy(db, phone, data)

        return jsonify({
            "succes": True,
            "pregnancy_id": preg_id,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Create pregnancy error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@pregnancy_bp.route("/pregnancy/list", methods=["POST"])
def list_pregnancies():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        user_doc = db.collection("users").document(phone).get()
        user_data = user_doc.to_dict() if user_doc.exists else {}
        active_id = user_data.get("active_pregnancy_id", "")

        pregnancies = get_all_pregnancies(db, phone)

        result = []
        for p in pregnancies:
            week = compute_pregnancy_week(p) if p.get("status") != "completed" else 0
            result.append({
                "id": p.get("id", ""),
                "status": p.get("status", ""),
                "pregnancy_method": p.get("pregnancy_method", ""),
                "lmp_date": p.get("lmp_date", ""),
                "manual_week": week,
                "due_date": p.get("due_date", ""),
                "actual_birth_date": p.get("actual_birth_date", ""),
                "doctor_name": p.get("doctor_name", ""),
                "doctor_phone": p.get("doctor_phone", ""),
                "created_at": p.get("created_at", ""),
                "is_active": p.get("id", "") == active_id,
            })

        return jsonify({
            "succes": True,
            "pregnancies": result,
            "active_id": active_id,
        }), 200

    except Exception as e:
        current_app.logger.error(f"List pregnancies error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@pregnancy_bp.route("/pregnancy/complete", methods=["POST"])
def complete_pregnancy():
    try:
        data = request.get_json()
        phone = data.get("phone")
        pregnancy_id = data.get("pregnancy_id", "")
        birth_date = data.get("birth_date", "")

        if not phone or not pregnancy_id or not birth_date:
            return jsonify({"succes": False, "erreur": "phone, pregnancy_id et birth_date requis"}), 400

        db = get_db()

        # Verify this is the active pregnancy
        active_id, _ = get_active_pregnancy(db, phone)
        if active_id != pregnancy_id:
            return jsonify({"succes": False, "erreur": "Cette grossesse n'est pas la grossesse active"}), 400

        finish_pregnancy(db, phone, pregnancy_id, birth_date)

        return jsonify({"succes": True}), 200

    except Exception as e:
        current_app.logger.error(f"Complete pregnancy error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@pregnancy_bp.route("/pregnancy/measures", methods=["POST"])
def pregnancy_measures():
    try:
        data = request.get_json()
        phone = data.get("phone")
        pregnancy_id = data.get("pregnancy_id")

        if not phone or not pregnancy_id:
            return jsonify({"succes": False, "erreur": "phone et pregnancy_id requis"}), 400

        db = get_db()

        from datetime import datetime, timedelta, timezone
        sept_jours = datetime.now(timezone.utc) - timedelta(days=7)

        docs = (
            db.collection("users").document(phone)
            .collection("pregnancies").document(pregnancy_id)
            .collection("measures")
            .where("timestamp", ">=", sept_jours)
            .order_by("timestamp", direction=firestore.Query.DESCENDING)
            .get()
        )

        mesures = []
        for doc in docs:
            m = doc.to_dict()
            ts = m.get("timestamp")
            mesures.append({
                "id": doc.id,
                "date": m.get("date", ""),
                "heure": m.get("heure", ""),
                "bpm": m.get("bpm", 0),
                "temperature": m.get("temperature", 0),
                "spo2": m.get("spo2", 0),
                "tension_s": m.get("tension_s", 0),
                "tension_d": m.get("tension_d", 0),
                "contractions": m.get("contractions", 0),
                "semaine": m.get("semaine", 0),
                "score": m.get("score", ""),
                "couleur": m.get("couleur", ""),
                "timestamp": ts.isoformat() if hasattr(ts, "isoformat") else str(ts),
            })

        return jsonify({"succes": True, "mesures": mesures}), 200

    except Exception as e:
        current_app.logger.error(f"Pregnancy measures error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@pregnancy_bp.route("/pregnancy/legacy-migrate", methods=["POST"])
def legacy_migrate():
    """One-time migration: create a pregnancy from legacy flat user data."""
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        db = get_db()
        user_doc = db.collection("users").document(phone).get()
        if not user_doc.exists:
            return jsonify({"succes": False, "erreur": "Utilisateur non trouvé"}), 404

        user_data = user_doc.to_dict()

        # Check if already migrated
        if user_data.get("active_pregnancy_id"):
            return jsonify({"succes": False, "erreur": "Déjà migré"}), 400

        preg_method = user_data.get("pregnancy_method", "")
        if not preg_method:
            return jsonify({"succes": False, "erreur": "Aucune donnée de grossesse à migrer"}), 400

        # Get linked doctor info
        doctor_phone = ""
        doctor_name = ""
        doctor_specialty = ""
        link_docs = db.collection("patient_links").where("patient_phone", "==", phone).limit(1).stream()
        for link in link_docs:
            ld = link.to_dict()
            doctor_phone = ld.get("doctor_phone", "")
            doctor_name = ld.get("doctor_name", "")
            doctor_specialty = ld.get("doctor_specialty", "")

        preg_id = create_pregnancy(db, phone, {
            "pregnancy_method": preg_method,
            "lmp_date": user_data.get("lmp_date", ""),
            "manual_week": user_data.get("manual_week", 0),
            "reference_date": user_data.get("reference_date", ""),
            "due_date": user_data.get("due_date", ""),
            "doctor_phone": doctor_phone,
            "doctor_name": doctor_name,
            "doctor_specialty": doctor_specialty,
        })

        # Move existing measures to pregnancy
        measures = db.collection("users").document(phone).collection("measures").stream()
        for m in measures:
            mv = m.to_dict()
            db.collection("users").document(phone).collection("pregnancies").document(preg_id).collection("measures").document(m.id).set(mv)

        return jsonify({"succes": True, "pregnancy_id": preg_id}), 200

    except Exception as e:
        current_app.logger.error(f"Legacy migrate error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500
