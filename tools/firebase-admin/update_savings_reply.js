const admin = require("firebase-admin");
const { randomUUID } = require("crypto");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const feedbackId = "0ECF73E5-28EB-4B00-82C1-34C290E73F57";
const oldReply = "Thanks for your feedback! We really appreciate it and we’ll include this in the next update.";
const newReply = "Thanks for your feedback! We really appreciate it and we’ll consider it for the future.";

async function updateSavingsReply() {
  const ref = db.collection("feedback").doc(feedbackId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      console.log(`[SKIP] Missing feedback ${feedbackId}`);
      return;
    }

    const data = snap.data() || {};
    const replies = Array.isArray(data.replies) ? data.replies : [];
    const updatedReplies = replies.map((r) => {
      if (r?.isFromDeveloper && (r?.content || "") === oldReply) {
        return {
          ...r,
          content: newReply,
          id: randomUUID(),
          creationDate: admin.firestore.Timestamp.now(),
        };
      }
      return r;
    });

    tx.update(ref, { replies: updatedReplies });
    console.log(`[WRITE] ${feedbackId}: developer reply updated`);
  });
}

updateSavingsReply().catch(console.error);
