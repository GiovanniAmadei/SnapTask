const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const feedbackIds = [
  "25F20CBB-DB63-4C44-90CC-601CDC362568",
  "0ECF73E5-28EB-4B00-82C1-34C290E73F57",
];

async function verifyReplies() {
  for (const id of feedbackIds) {
    const snap = await db.collection("feedback").doc(id).get();
    const data = snap.data() || {};
    const replies = Array.isArray(data.replies) ? data.replies : [];
    const developerReplies = replies.filter((r) => r?.isFromDeveloper);
    console.log(JSON.stringify({
      id,
      title: data.title,
      totalReplies: replies.length,
      developerReplies: developerReplies.length,
      lastDeveloperReply: developerReplies.length ? developerReplies[developerReplies.length - 1].content : null
    }));
  }
}

verifyReplies().catch(console.error);
