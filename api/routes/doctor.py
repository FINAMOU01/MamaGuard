import uuid
from flask import Blueprint, request, jsonify, current_app
from firebase_admin import firestore
from services.firebase_service import get_db

doctor_bp = Blueprint("doctor", __name__)


@doctor_bp.route("/doctor/register", methods=["POST"])
def register_doctor():
    try:
        data = request.get_json()
        phone = data.get("phone")
        name = data.get("name", "Médecin")
        specialty = data.get("specialty", "Généraliste")

        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        existing = get_db().collection("doctors").where("phone", "==", phone).stream()
        existing_docs = list(existing)

        liaison_code = str(uuid.uuid4())[:6].upper()
        if existing_docs:
            doc = existing_docs[0]
            d = doc.to_dict()
            return jsonify({
                "succes": True,
                "deja_existant": True,
                "id": doc.id,
                "liaison_code": d.get("liaison_code", liaison_code),
            }), 200

        doc_ref = get_db().collection("doctors").document()
        doc_ref.set({
            "phone": phone,
            "name": name,
            "specialty": specialty,
            "liaison_code": liaison_code,
            "created_at": firestore.SERVER_TIMESTAMP,
        })
        return jsonify({
            "succes": True,
            "id": doc_ref.id,
            "liaison_code": liaison_code,
            "name": name,
            "specialty": specialty,
        }), 200

    except Exception as e:
        current_app.logger.error(f"Doctor register error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/doctor/lookup", methods=["POST"])
def lookup_doctor():
    try:
        data = request.get_json()
        code = data.get("code", "").strip().upper()

        if not code or len(code) < 4:
            return jsonify({"succes": False, "erreur": "Code de liaison invalide"}), 400

        docs = get_db().collection("doctors").where("liaison_code", "==", code).limit(1).stream()
        for doc in docs:
            d = doc.to_dict()
            return jsonify({
                "succes": True,
                "id": doc.id,
                "name": d.get("name", "Médecin"),
                "phone": d.get("phone", ""),
                "specialty": d.get("specialty", "Généraliste"),
            }), 200

        return jsonify({"succes": False, "erreur": "Aucun médecin trouvé avec ce code"}), 404

    except Exception as e:
        current_app.logger.error(f"Doctor lookup error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/patient/link-doctor", methods=["POST"])
def link_patient_to_doctor():
    try:
        data = request.get_json()
        phone = data.get("phone")
        code = data.get("code", "").strip().upper()

        if not phone or not code:
            return jsonify({"succes": False, "erreur": "phone et code requis"}), 400

        doctor_docs = list(get_db().collection("doctors").where("liaison_code", "==", code).limit(1).stream())
        if not doctor_docs:
            return jsonify({"succes": False, "erreur": "Code de liaison invalide"}), 404

        doctor = doctor_docs[0]
        doctor_data = doctor.to_dict()

        link_ref = get_db().collection("patient_links").document()
        link_ref.set({
            "patient_phone": phone,
            "doctor_id": doctor.id,
            "doctor_name": doctor_data.get("name", "Médecin"),
            "doctor_phone": doctor_data.get("phone", ""),
            "doctor_specialty": doctor_data.get("specialty", "Généraliste"),
            "liaison_code": code,
            "created_at": firestore.SERVER_TIMESTAMP,
        })

        return jsonify({
            "succes": True,
            "doctor_name": doctor_data.get("name", "Médecin"),
            "doctor_phone": doctor_data.get("phone", ""),
            "doctor_specialty": doctor_data.get("specialty", "Généraliste"),
        }), 200

    except Exception as e:
        current_app.logger.error(f"Link doctor error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500


@doctor_bp.route("/patient/doctor-info", methods=["POST"])
def get_linked_doctor():
    try:
        data = request.get_json()
        phone = data.get("phone")
        if not phone:
            return jsonify({"succes": False, "erreur": "phone requis"}), 400

        docs = get_db().collection("patient_links").where("patient_phone", "==", phone).limit(1).stream()
        for doc in docs:
            d = doc.to_dict()
            return jsonify({"succes": True, "docteur": d}), 200

        return jsonify({"succes": False, "erreur": "Aucun médecin lié"}), 404

    except Exception as e:
        current_app.logger.error(f"Doctor info error: {e}")
        return jsonify({"succes": False, "erreur": str(e)}), 500
