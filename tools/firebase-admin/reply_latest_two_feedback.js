const admin = require("firebase-admin");
const { randomUUID } = require("crypto");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const feedbackIds = [
  "25F20CBB-DB63-4C44-90CC-601CDC362568",
  "0ECF73E5-28EB-4B00-82C1-34C290E73F57",
];
const replyContent = "Thanks for your feedback! We really appreciate it and we’ll include this in the next update.";

async function replyLatestTwo() {
  for (const id of feedbackIds) {
    const ref = db.collection("feedback").doc(id);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        console.log(`[SKIP] Missing feedback ${id}`);
        return;
      }

      const data = snap.data() || {};
      const replies = Array.isArray(data.replies) ? data.replies : [];
      const alreadyPresent = replies.some((r) => r?.isFromDeveloper && (r?.content || "") === replyContent);

      if (alreadyPresent) {
        console.log(`[OK] ${id}: reply already present`);
        return;
      }

      const replyData = {
        id: randomUUID(),
        content: replyContent,
        authorId: "giovanni_amadei_dev_id",
        authorName: "Giovanni (Developer)",
        creationDate: admin.firestore.Timestamp.now(),
        isFromDeveloper: true,
        likes: 0,
      };

      tx.update(ref, {
        replies: admin.firestore.FieldValue.arrayUnion(replyData),
      });

      console.log(`[WRITE] ${id}: developer reply added`);
    });
  }
}

replyLatestTwo().catch(console.error);
