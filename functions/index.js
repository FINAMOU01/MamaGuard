const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger, setGlobalOptions } = require("firebase-functions");
const admin = require("firebase-admin");
const { sendSms } = require("./services/twilio");

setGlobalOptions({ region: "europe-west1" });

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ============================================================
// #1 + #2 + #3 + #4 — onRiskDetected (T+0)
// ============================================================
exports.onRiskDetected = onDocumentCreated(
    "alertes/{alertId}",
    async (event) => {
      const snap = event.data;
      const alert = snap.data();
      const alertId = event.params.alertId;
      const now = admin.firestore.Timestamp.now();

      logger.info(`[onRiskDetected] Alert ${alertId} - Score: ${alert.score}`);

      const { patientId, patientName, phone, score, alertes,
        emergencyContacts, doctorPhone, fcmToken } = alert;

      const isHighRisk = score === "Eleve";
      const isModerate = score === "Modere";

      if (!isHighRisk && !isModerate) {
        await snap.ref.update({
          escalated: false,
          status: "surveillance",
          vu: true,
          processedAt: now,
        });
        return null;
      }

      // Marquer comme en cours
      await snap.ref.update({
        escalated: true,
        status: "escalade_en_cours",
        vu: false,
        processedAt: now,
        t0Sent: false,
        t10Sent: false,
        t20Sent: false,
      });

      // --- T+0 : FCM push haute priorité (#3) ---
      if (fcmToken) {
        const fcmPayload = {
          token: fcmToken,
          notification: {
            title: "🚨 MamaGuard - Alerte sanitaire",
            body: `Votre risque est ${score}. ${(alertes || []).slice(0, 2).join(", ")}`,
          },
          data: {
            alertId,
            score,
            type: "risk_alert",
            sound: "alarm",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "mamaguard_critical",
              priority: "max",
              sound: "alarm",
              vibrationPattern: [1000, 1000, 1000],
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "alarm.caf",
                badge: 1,
                alert: { title: "MamaGuard", body: `Risque ${score}` },
              },
            },
          },
        };

        try {
          const fcmResult = await messaging.send(fcmPayload);
          logger.info(`[FCM] Push sent to ${patientName} - ${fcmResult}`);
        } catch (err) {
          logger.error(`[FCM] Push failed for ${patientName}`, err);
        }
      }

      // --- T+0 : SMS via Twilio (#4) ---
      const smsMsg = `MamaGuard ALERTE: ${patientName}, votre risque est "${score}". ${(alertes || []).join(", ")}. Consultez un medecin immediatement.`;

      if (phone) {
        try {
          const smsResult = await sendSms(phone, smsMsg);
          logger.info(`[SMS] T+0 sent to patient ${phone} - ${smsResult.sid}`);
          await snap.ref.update({
            t0Sent: true,
            t0Sid: smsResult.sid,
            t0SentAt: now,
          });
        } catch (err) {
          logger.error(`[SMS] T+0 failed for patient ${phone}`, err);
          await snap.ref.update({ t0Error: err.message });
        }
      }

      // --- Planifier T+10 et T+20 (#2) ---
      const steps = [];

      if (emergencyContacts && emergencyContacts.length > 0) {
        steps.push({
          type: "t10",
          label: "Contacter proches",
          plannedAt: admin.firestore.Timestamp.fromMillis(
              now.toMillis() + 10 * 60 * 1000,
          ),
          executed: false,
        });
      }

      if (doctorPhone) {
        steps.push({
          type: "t20",
          label: "Contacter medecin",
          plannedAt: admin.firestore.Timestamp.fromMillis(
              now.toMillis() + 20 * 60 * 1000,
          ),
          executed: false,
        });
      }

      const batch = db.batch();
      for (const step of steps) {
        const stepRef = snap.ref.collection("steps").doc();
        batch.set(stepRef, step);
      }
      await batch.commit();

      logger.info(`[onRiskDetected] Alert ${alertId} — T+0 done, ${steps.length} steps scheduled`);
      return null;
    },
);

// ============================================================
// #2 — Escalade T+10 et T+20 (scheduled every minute)
// ============================================================
exports.processPendingSteps = onSchedule(
    "every 1 minutes",
    async (event) => {
      logger.info("[processPendingSteps] Checking pending escalation steps...");
      const now = admin.firestore.Timestamp.now();

      // Get all pending steps across all alerts
      const alertsSnap = await db.collection("alertes")
          .where("vu", "==", false)
          .where("escalated", "==", true)
          .get();

      if (alertsSnap.empty) {
        logger.info("[processPendingSteps] No pending alerts");
        return null;
      }

      let processed = 0;

      for (const alertDoc of alertsSnap.docs) {
        const alertData = alertDoc.data();

        // Skip alerts that are already fully escalated
        if (alertData.t10Sent && alertData.t20Sent) continue;

        const stepsSnap = await alertDoc.ref.collection("steps")
            .where("executed", "==", false)
            .where("plannedAt", "<=", now)
            .get();

        if (stepsSnap.empty) continue;

        for (const stepDoc of stepsSnap.docs) {
          const step = stepDoc.data();
          const stepType = step.type;
          const stepTime = stepType === "t10" ? "T+10" : "T+20";

          logger.info(`[${stepTime}] Processing ${stepType} for alert ${alertDoc.id}`);

          try {
            if (stepType === "t10") {
              // SMS to emergency contacts
              for (const contact of (alertData.emergencyContacts || [])) {
                const msg = `MamaGuard URGENT: ${alertData.patientName} presente un risque ${alertData.score}. ${(alertData.alertes || []).join(", ")}. Veuillez contacter votre proche ou les urgences.`;
                await sendSms(contact.phone, msg);
                logger.info(`[T+10] SMS sent to ${contact.relation} (${contact.phone})`);
              }
              await alertDoc.ref.update({ t10Sent: true, t10SentAt: now });
            }

            if (stepType === "t20") {
              // SMS to doctor
              const msg = `MamaGuard ESCALADE: Patiente ${alertData.patientName} - Risque ${alertData.score}. ${(alertData.alertes || []).join(", ")}. Consultez le dossier patient.`;
              await sendSms(alertData.doctorPhone, msg);
              logger.info(`[T+20] SMS sent to doctor (${alertData.doctorPhone})`);
              await alertDoc.ref.update({ t20Sent: true, t20SentAt: now });
            }

            await stepDoc.ref.update({ executed: true, executedAt: now });
            processed++;

            // Mark alert as fully escalated when all steps done
            if (alertData.t10Sent && alertData.t20Sent) {
              await alertDoc.ref.update({ status: "escalade_terminee" });
            }
          } catch (err) {
            logger.error(`[${stepTime}] Failed for alert ${alertDoc.id}`, err);
            await stepDoc.ref.update({ error: err.message });
          }
        }
      }

      logger.info(`[processPendingSteps] Processed ${processed} steps`);
      return null;
    },
);

// ============================================================
// #6 — onAlertSeen (callable) Marquer VU + annuler escalade
// ============================================================
exports.onAlertSeen = onCall(
    async (request) => {
      const { alertId } = request.data;

      if (!alertId) {
        return { success: false, error: "alertId requis" };
      }

      const alertRef = db.collection("alertes").doc(alertId);
      const alertSnap = await alertRef.get();

      if (!alertSnap.exists) {
        return { success: false, error: "Alerte introuvable" };
      }

      // Cancel pending steps
      const stepsSnap = await alertRef.collection("steps")
          .where("executed", "==", false)
          .get();

      const batch = db.batch();
      stepsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
          executed: true,
          cancelled: true,
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      batch.update(alertRef, {
        vu: true,
        vuAt: admin.firestore.FieldValue.serverTimestamp(),
        vuBy: request.auth ? request.auth.uid : "unknown",
        status: "alerte_vue",
      });

      await batch.commit();

      logger.info(`[onAlertSeen] Alert ${alertId} marked as VU by ${request.auth ? request.auth.uid : "unknown"}`);

      return { success: true, message: "Alerte marquee comme vue" };
    },
);

// ============================================================
// #5 — Test helper : Créer une alerte de test
// ============================================================
exports.createTestAlert = onCall(
    async (request) => {
      const testAlert = {
        patientId: request.data.patientId || "test_patient_001",
        patientName: request.data.patientName || "Marie Claire",
        phone: process.env.TWILIO_PHONE_NUMBER || "+237653844244",
        score: request.data.score || "Eleve",
        alertes: request.data.alertes || [
          "Tachycardie severe",
          "Hypertension severe",
        ],
        emergencyContacts: request.data.emergencyContacts || [
          { name: "Paul", phone: process.env.TWILIO_PHONE_NUMBER, relation: "conjoint" },
        ],
        doctorPhone: process.env.TWILIO_PHONE_NUMBER || "+237653844244",
        fcmToken: request.data.fcmToken || null,
        vu: false,
        escalated: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      const doc = await db.collection("alertes").add(testAlert);
      logger.info(`[createTestAlert] Test alert created: ${doc.id}`);
      return { success: true, alertId: doc.id };
    },
);
