"""One-time migration script: move existing flat pregnancy data to pregnancy subcollection."""
import sys
import os

# Must be set before importing firebase_service
_script_dir = os.path.dirname(os.path.abspath(__file__))
if 'FIRESTORE_EMULATOR_HOST' in os.environ:
    del os.environ['FIRESTORE_EMULATOR_HOST']
os.environ['FIREBASE_SERVICE_ACCOUNT_PATH'] = os.path.join(
    os.path.dirname(_script_dir), 'credentials', 'firebase-service-account.json'
)
os.environ['FIREBASE_DATABASE_URL'] = 'https://mamaguard-1f712.firebaseio.com'

sys.path.insert(0, os.path.join(_script_dir, 'api'))

from services.firebase_service import get_db
from services.pregnancy_service import (
    get_active_pregnancy,
    create_pregnancy,
)
from firebase_admin import firestore


def migrate_all_users():
    db = get_db()
    if not db:
        print("Firebase not configured")
        return

    users = db.collection("users").stream()
    migrated = 0
    skipped_no_data = 0
    skipped_already = 0
    errors = []

    for user_doc in users:
        phone = user_doc.id
        user_data = user_doc.to_dict()

        try:
            # Skip if already migrated
            if user_data.get("active_pregnancy_id"):
                print(f"SKIP {phone}: already migrated (active_pregnancy_id={user_data['active_pregnancy_id']})")
                skipped_already += 1
                continue

            preg_method = user_data.get("pregnancy_method", "")
            if not preg_method:
                print(f"SKIP {phone}: no pregnancy data")
                skipped_no_data += 1
                continue

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

            # Create pregnancy
            preg_id = create_pregnancy(db, phone, {
                "pregnancy_method": preg_method,
                "lmp_date": user_data.get("lmp_date", ""),
                "manual_week": user_data.get("manual_week", 0),
                "reference_date": user_data.get("reference_date", ""),
                "due_date": "",
                "doctor_phone": doctor_phone,
                "doctor_name": doctor_name,
                "doctor_specialty": doctor_specialty,
            })

            # Move measures
            measures = list(db.collection("users").document(phone).collection("measures").stream())
            for m in measures:
                mv = m.to_dict()
                db.collection("users").document(phone).collection("pregnancies").document(preg_id).collection("measures").document(m.id).set(mv)
            print(f"MIGRATED {phone}: {preg_method}, {len(measures)} measures moved, doctor={doctor_name}")

            # Remove old flat fields (optional)
            db.collection("users").document(phone).update({
                "pregnancy_method": firestore.DELETE_FIELD,
                "lmp_date": firestore.DELETE_FIELD,
                "manual_week": firestore.DELETE_FIELD,
                "reference_date": firestore.DELETE_FIELD,
                "pregnancy_week": firestore.DELETE_FIELD,
                "due_date": firestore.DELETE_FIELD,
            })

            migrated += 1

        except Exception as e:
            print(f"ERROR {phone}: {e}")
            errors.append((phone, str(e)))

    print(f"\n=== Migration complete ===")
    print(f"Migrated: {migrated}")
    print(f"Skipped (no data): {skipped_no_data}")
    print(f"Skipped (already): {skipped_already}")
    print(f"Errors: {len(errors)}")
    for phone, err in errors:
        print(f"  - {phone}: {err}")


if __name__ == "__main__":
    migrate_all_users()
