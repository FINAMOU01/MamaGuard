import hashlib
import random
from datetime import datetime, timezone, timedelta
from flask import Blueprint, request, session, redirect, url_for, render_template, flash, current_app
from firebase_admin import firestore
from services.firebase_service import get_db
from services.sms_service import SmsService

admin_bp = Blueprint("admin", __name__)
sms_service = SmsService()


def _ensure_admin():
    if not session.get("admin_email"):
        return False
    return True


def _hash_password(password):
    return hashlib.sha256(password.encode()).hexdigest()


def _generate_code(length=6):
    return "".join([str(random.randint(0, 9)) for _ in range(length)])


def _now_iso():
    return datetime.now(timezone.utc).isoformat()


def _doctor_to_dict(doc):
    d = doc.to_dict()
    ts = d.get("created_at")
    return {
        "id": doc.id,
        "name": d.get("name", ""),
        "phone": d.get("phone", ""),
        "specialty": d.get("specialty", ""),
        "hospital": d.get("hospital", ""),
        "status": d.get("status", ""),
        "liaison_code": d.get("liaison_code", ""),
        "created_at": ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else "",
    }


# ─── Auth ──────────────────────────────────────────────────────────────────

@admin_bp.route("/admin/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        email = request.form.get("email", "").strip().lower()
        password = request.form.get("password", "")

        db = get_db()
        if db:
            docs = db.collection("admins").where("email", "==", email).limit(1).stream()
            for doc in docs:
                d = doc.to_dict()
                if d.get("password_hash") == _hash_password(password) and d.get("actif", True):
                    session["admin_email"] = email
                    session["admin_name"] = d.get("name", "Admin")
                    return redirect(url_for("admin.dashboard"))

        flash("Email ou mot de passe incorrect", "error")
    return render_template("admin/login.html")


@admin_bp.route("/admin/logout")
def logout():
    session.clear()
    return redirect(url_for("admin.login"))


# ─── Dashboard ─────────────────────────────────────────────────────────────

@admin_bp.route("/admin/dashboard")
def dashboard():
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    stats = {"pending": 0, "valide": 0, "rejete": 0, "desactive": 0, "patients": 0, "admins": 0}

    if db:
        try:
            stats["pending"] = len(list(db.collection("doctors").where("status", "==", "en_attente").limit(1000).stream()))
            stats["valide"] = len(list(db.collection("doctors").where("status", "==", "valide").limit(1000).stream()))
            stats["rejete"] = len(list(db.collection("doctors").where("status", "==", "rejete").limit(1000).stream()))
            stats["desactive"] = len(list(db.collection("doctors").where("status", "==", "desactive").limit(1000).stream()))
            stats["patients"] = len(list(db.collection("users").limit(1000).stream()))
            stats["admins"] = len(list(db.collection("admins").limit(1000).stream()))
        except Exception as e:
            current_app.logger.error(f"Dashboard stats error: {e}")
            flash(f"Erreur lors du chargement des statistiques: {e}", "error")

    return render_template("admin/dashboard.html", stats=stats)


# ─── Pending doctors list ──────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/en-attente")
def pending_doctors():
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    doctors = []
    if db:
        try:
            docs = db.collection("doctors").where("status", "==", "en_attente").stream()
            doctors = [_doctor_to_dict(d) for d in docs]
        except Exception as e:
            current_app.logger.error(f"Pending doctors error: {e}")
            flash(f"Erreur Firebase: {e}", "error")

    return render_template("admin/pending_doctors.html", doctors=doctors)


# ─── Doctor details ────────────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/<doctor_id>")
def doctor_details(doctor_id):
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    doctor = None
    if db:
        doc = db.collection("doctors").document(doctor_id).get()
        if doc.exists:
            doctor = _doctor_to_dict(doc)
            patient_links = list(db.collection("patient_links").where("doctor_id", "==", doctor_id).limit(100).stream())
            doctor["patient_count"] = len(patient_links)

    if not doctor:
        flash("Médecin introuvable", "error")
        return redirect(url_for("admin.pending_doctors"))

    return render_template("admin/doctor_details.html", doctor=doctor)


# ─── Validate doctor ───────────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/<doctor_id>/valider", methods=["POST"])
def validate_doctor(doctor_id):
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    if not db:
        flash("Erreur de connexion à la base de données", "error")
        return redirect(url_for("admin.pending_doctors"))

    doc_ref = db.collection("doctors").document(doctor_id)
    doc = doc_ref.get()
    if not doc.exists:
        flash("Médecin introuvable", "error")
        return redirect(url_for("admin.pending_doctors"))

    doctor_data = doc.to_dict()
    liaison_code = _generate_code()
    name = doctor_data.get("name", "Médecin")
    phone = doctor_data.get("phone", "")

    doc_ref.update({
        "status": "valide",
        "liaison_code": liaison_code,
        "validated_at": firestore.SERVER_TIMESTAMP,
        "validated_by": session.get("admin_email", ""),
    })

    if phone:
        msg = f"MamaGuard: {name}, votre inscription a ete validee. Votre code de liaison est {liaison_code}. Partagez-le avec vos patientes."
        sms_service.send(phone, msg)

    flash(f"Médecin {name} validé avec succès. Code: {liaison_code}", "success")
    return redirect(url_for("admin.pending_doctors"))


# ─── Reject doctor ─────────────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/<doctor_id>/rejeter", methods=["POST"])
def reject_doctor(doctor_id):
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    if not db:
        flash("Erreur de connexion à la base de données", "error")
        return redirect(url_for("admin.pending_doctors"))

    doc_ref = db.collection("doctors").document(doctor_id)
    doc = doc_ref.get()
    if not doc.exists:
        flash("Médecin introuvable", "error")
        return redirect(url_for("admin.pending_doctors"))

    doctor_data = doc.to_dict()
    name = doctor_data.get("name", "Médecin")
    phone = doctor_data.get("phone", "")

    doc_ref.update({
        "status": "rejete",
        "rejected_at": firestore.SERVER_TIMESTAMP,
        "rejected_by": session.get("admin_email", ""),
    })

    if phone:
        msg = f"MamaGuard: {name}, votre inscription n'a pas ete retenue. Contactez le support pour plus d'informations."
        sms_service.send(phone, msg)

    flash(f"Médecin {name} rejeté", "info")
    return redirect(url_for("admin.pending_doctors"))


# ─── Deactivate doctor ─────────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/<doctor_id>/desactiver", methods=["POST"])
def deactivate_doctor(doctor_id):
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    if not db:
        flash("Erreur de connexion à la base de données", "error")
        return redirect(url_for("admin.validated_doctors"))

    doc_ref = db.collection("doctors").document(doctor_id)
    doc = doc_ref.get()
    if not doc.exists:
        flash("Médecin introuvable", "error")
        return redirect(url_for("admin.validated_doctors"))

    doctor_data = doc.to_dict()
    name = doctor_data.get("name", "Médecin")
    phone = doctor_data.get("phone", "")

    doc_ref.update({
        "status": "desactive",
        "deactivated_at": firestore.SERVER_TIMESTAMP,
        "deactivated_by": session.get("admin_email", ""),
    })

    if phone:
        msg = f"MamaGuard: Dr {name}, votre compte medecin a ete desactive. Contactez l'administration."
        sms_service.send(phone, msg)

    flash(f"Compte de {name} désactivé", "info")
    return redirect(url_for("admin.validated_doctors"))


# ─── Reactivate doctor ─────────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/<doctor_id>/reactiver", methods=["POST"])
def reactivate_doctor(doctor_id):
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    if not db:
        flash("Erreur de connexion à la base de données", "error")
        return redirect(url_for("admin.validated_doctors"))

    doc_ref = db.collection("doctors").document(doctor_id)
    doc = doc_ref.get()
    if not doc.exists:
        flash("Médecin introuvable", "error")
        return redirect(url_for("admin.validated_doctors"))

    doctor_data = doc.to_dict()
    name = doctor_data.get("name", "Médecin")
    phone = doctor_data.get("phone", "")
    liaison_code = doctor_data.get("liaison_code", _generate_code())

    if not doctor_data.get("liaison_code"):
        doc_ref.update({"liaison_code": liaison_code})

    doc_ref.update({
        "status": "valide",
        "reactivated_at": firestore.SERVER_TIMESTAMP,
        "reactivated_by": session.get("admin_email", ""),
    })

    if phone:
        msg = f"MamaGuard: Dr {name}, votre compte medecin a ete reactive. Vous pouvez des a present utiliser votre code de liaison."
        sms_service.send(phone, msg)

    flash(f"Compte de {name} réactivé", "success")
    return redirect(url_for("admin.validated_doctors"))


# ─── Validated doctors list ────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/valides")
def validated_doctors():
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    doctors = []
    if db:
        try:
            docs = db.collection("doctors").where("status", "==", "valide").stream()
            doctors = [_doctor_to_dict(d) for d in docs]
        except Exception as e:
            current_app.logger.error(f"Validated doctors error: {e}")
            flash(f"Erreur Firebase: {e}", "error")

    return render_template("admin/validated_doctors.html", doctors=doctors)


# ─── Inactive doctors list ─────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/desactives")
def inactive_doctors():
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    doctors = []
    if db:
        try:
            for status in ("desactive", "rejete"):
                docs = db.collection("doctors").where("status", "==", status).stream()
                doctors.extend([_doctor_to_dict(d) for d in docs])
        except Exception as e:
            current_app.logger.error(f"Inactive doctors error: {e}")
            flash(f"Erreur Firebase: {e}", "error")

    return render_template("admin/inactive_doctors.html", doctors=doctors)


# ─── Search doctors ────────────────────────────────────────────────────────

@admin_bp.route("/admin/medecins/recherche", methods=["GET", "POST"])
def search_doctors():
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    query = ""
    results = []
    db = get_db()

    if request.method == "POST":
        query = request.form.get("query", "").strip().lower()
        if query and db:
            all_docs = db.collection("doctors").stream()
            for doc in all_docs:
                d = doc.to_dict()
                if query in d.get("name", "").lower() or query in d.get("hospital", "").lower() or query in d.get("phone", ""):
                    results.append(_doctor_to_dict(doc))

    return render_template("admin/search_doctors.html", query=query, results=results)


# ─── Admins list ───────────────────────────────────────────────────────────

@admin_bp.route("/admin/admins")
def admin_list():
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    admins = []
    if db:
        docs = db.collection("admins").order_by("created_at", direction=firestore.Query.DESCENDING).stream()
        for doc in docs:
            d = doc.to_dict()
            ts = d.get("created_at")
            admins.append({
                "id": doc.id,
                "email": d.get("email", ""),
                "name": d.get("name", ""),
                "phone": d.get("phone", ""),
                "actif": d.get("actif", True),
                "created_at": ts.isoformat() if hasattr(ts, "isoformat") else str(ts) if ts else "",
            })

    return render_template("admin/admins.html", admins=admins)


# ─── Create admin ──────────────────────────────────────────────────────────

@admin_bp.route("/admin/admins/creer", methods=["POST"])
def create_admin():
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    name = request.form.get("name", "").strip()
    email = request.form.get("email", "").strip().lower()
    phone = request.form.get("phone", "").strip()
    password = request.form.get("password", "")

    if not all([name, email, phone, password]):
        flash("Tous les champs sont requis", "error")
        return redirect(url_for("admin.admin_list"))

    db = get_db()
    if not db:
        flash("Erreur de connexion à la base de données", "error")
        return redirect(url_for("admin.admin_list"))

    existing = list(db.collection("admins").where("email", "==", email).limit(1).stream())
    if existing:
        flash("Un administrateur avec cet email existe déjà", "error")
        return redirect(url_for("admin.admin_list"))

    db.collection("admins").document().set({
        "name": name,
        "email": email,
        "phone": phone,
        "password_hash": _hash_password(password),
        "actif": True,
        "created_at": firestore.SERVER_TIMESTAMP,
        "created_by": session.get("admin_email", ""),
    })

    if phone:
        msg = f"MamaGuard: {name}, vous avez ete inscrit comme administrateur. Email: {email}. Connectez-vous sur l'interface admin."
        sms_service.send(phone, msg)

    flash(f"Admin {name} créé avec succès. Un SMS a été envoyé.", "success")
    return redirect(url_for("admin.admin_list"))


# ─── Revoke admin ──────────────────────────────────────────────────────────

@admin_bp.route("/admin/admins/<admin_id>/revoquer", methods=["POST"])
def revoke_admin(admin_id):
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    if not db:
        flash("Erreur de connexion à la base de données", "error")
        return redirect(url_for("admin.admin_list"))

    doc_ref = db.collection("admins").document(admin_id)
    doc = doc_ref.get()
    if not doc.exists:
        flash("Administrateur introuvable", "error")
        return redirect(url_for("admin.admin_list"))

    d = doc.to_dict()
    if d.get("email") == session.get("admin_email"):
        flash("Vous ne pouvez pas révoquer votre propre compte", "error")
        return redirect(url_for("admin.admin_list"))

    doc_ref.update({"actif": False, "revoked_at": firestore.SERVER_TIMESTAMP})
    flash(f"Admin {d.get('name', '')} révoqué", "info")
    return redirect(url_for("admin.admin_list"))


# ─── Statistics ────────────────────────────────────────────────────────────

@admin_bp.route("/admin/statistiques")
def statistics():
    if not _ensure_admin():
        return redirect(url_for("admin.login"))

    db = get_db()
    stats = {
        "patients_actifs": 0,
        "medecins_valides": 0,
        "medecins_en_attente": 0,
        "alertes_semaine": 0,
        "alertes_eleve": 0,
        "alertes_modere": 0,
        "consultations_semaine": 0,
        "alerte_jours": [],
    }

    if db:
        stats["patients_actifs"] = len(list(db.collection("users").limit(1000).stream()))
        stats["medecins_valides"] = len(list(db.collection("doctors").where("status", "==", "valide").limit(1000).stream()))
        stats["medecins_en_attente"] = len(list(db.collection("doctors").where("status", "==", "en_attente").limit(1000).stream()))

        now = datetime.now(timezone.utc)
        week_ago = now - timedelta(days=7)
        month_ago = now - timedelta(days=30)

        try:
            alerts = db.collection("alertes").where("createdAt", ">=", week_ago).stream()
            for a in alerts:
                ad = a.to_dict()
                stats["alertes_semaine"] += 1
                score = ad.get("score", "").lower()
                if score in ("eleve", "critique", "danger"):
                    stats["alertes_eleve"] += 1
                else:
                    stats["alertes_modere"] += 1
        except Exception:
            pass

        try:
            consultations = db.collection("consultations").where("created_at", ">=", week_ago).stream()
            stats["consultations_semaine"] = sum(1 for _ in consultations)
        except Exception:
            pass

        try:
            days = {}
            for i in range(30):
                day = (now - timedelta(days=i)).strftime("%Y-%m-%d")
                days[day] = 0
            alerts_month = db.collection("alertes").where("createdAt", ">=", month_ago).stream()
            for a in alerts_month:
                ad = a.to_dict()
                ts = ad.get("createdAt")
                if hasattr(ts, "strftime"):
                    day_key = ts.strftime("%Y-%m-%d")
                elif ts:
                    day_key = str(ts)[:10]
                else:
                    continue
                if day_key in days:
                    days[day_key] += 1
            stats["alerte_jours"] = [{"date": k, "count": v} for k, v in sorted(days.items())]
        except Exception:
            pass

    return render_template("admin/statistics.html", stats=stats)
