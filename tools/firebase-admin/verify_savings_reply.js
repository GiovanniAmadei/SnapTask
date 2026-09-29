const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const feedbackId = "0ECF73E5-28EB-4B00-82C1-34C290E73F57";

async function verifySavingsReply() {
  const snap = await db.collection("feedback").doc(feedbackId).get();
  const data = snap.data() || {};
  const replies = Array.isArray(data.replies) ? data.replies : [];
  const developerReplies = replies.filter((r) => r?.isFromDeveloper);
  console.log(JSON.stringify({
    id: feedbackId,
    title: data.title,
    developerReplies: developerReplies.map((r) => r.content)
  }));
}

verifySavingsReply().catch(console.error);
