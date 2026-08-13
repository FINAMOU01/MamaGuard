const functions = require("firebase-functions");

const twilioConfig = {
  accountSid: process.env.TWILIO_ACCOUNT_SID,
  authToken: process.env.TWILIO_AUTH_TOKEN,
  fromNumber: process.env.TWILIO_PHONE_NUMBER,
};

let client = null;

function getClient() {
  if (!client && twilioConfig.accountSid && twilioConfig.authToken) {
    client = require("twilio")(
        twilioConfig.accountSid,
        twilioConfig.authToken,
    );
  }
  return client;
}

function truncate(msg, max = 160) {
  const now = new Date().toLocaleString("fr-FR");
  const prefix = `[${now}] `;
  const available = max - prefix.length;
  if (msg.length + prefix.length > max) {
    return `${prefix}${msg.substring(0, available)}`;
  }
  return `${prefix}${msg}`;
}

async function sendSms(to, message) {
  const c = getClient();
  if (!c) {
    throw new Error("Twilio non configuré");
  }
  const body = truncate(message);
  const result = await c.messages.create({
    body,
    from: twilioConfig.fromNumber,
    to,
  });
  functions.logger.info(`[Twilio] SMS sent to ${to} - SID: ${result.sid}`);
  return { sid: result.sid, status: result.status };
}

module.exports = { sendSms };
