const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function inspect() {
  const feedbackSnapshot = await db.collection("feedback")
    .where("title", "==", "Savings in finance")
    .get();

  console.log(`Savings in finance docs: ${feedbackSnapshot.size}`);
  for (const doc of feedbackSnapshot.docs) {
    const data = doc.data() || {};
    const replies = Array.isArray(data.replies) ? data.replies : [];
    console.log(JSON.stringify({
      id: doc.id,
      title: data.title,
      replies: replies.map((r) => ({
        content: r.content,
        isFromDeveloper: r.isFromDeveloper,
        authorName: r.authorName
      }))
    }));
  }

  const comingSoonSnapshot = await db.collection("coming_soon").get();
  console.log(`coming_soon docs: ${comingSoonSnapshot.size}`);
  for (const doc of comingSoonSnapshot.docs) {
    const data = doc.data() || {};
    console.log(JSON.stringify({ id: doc.id, title: data.title }));
  }
}

inspect().catch(console.error);
