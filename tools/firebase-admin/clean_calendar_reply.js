const admin = require("firebase-admin");

const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function cleanCalendarReply() {
  const title = "Calendar Integration";
  const snapshot = await db.collection("feedback")
    .where("title", "==", title)
    .get();

  if (snapshot.empty) {
    console.log(`[SKIP] No feedback found with title == '${title}'`);
    return;
  }

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const replies = Array.isArray(data.replies) ? data.replies : [];
    
    // Filter out the old developer reply
    const filteredReplies = replies.filter(r => {
      if (!r.isFromDeveloper) return true;
      // Keep only the new correct one if already present, or remove the one mentioning "next update"
      return !r.content.includes("we’ll work on this for the next update");
    });

    if (replies.length !== filteredReplies.length) {
      await doc.ref.update({ replies: filteredReplies });
      console.log(`[CLEAN] '${title}' (${doc.id}): removed old developer reply`);
    } else {
      console.log(`[OK] '${title}' (${doc.id}): no old reply found to remove`);
    }
  }
}

cleanCalendarReply().catch(console.error);
