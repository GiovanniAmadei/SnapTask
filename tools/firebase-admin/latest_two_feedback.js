const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function listLatestTwoFeedback() {
  const snapshot = await db.collection("feedback")
    .orderBy("creationDate", "desc")
    .limit(2)
    .get();

  console.log(`Found ${snapshot.size} latest feedback items:`);
  snapshot.forEach((doc) => {
    const data = doc.data() || {};
    console.log(JSON.stringify({
      id: doc.id,
      title: data.title,
      creationDate: data.creationDate,
      repliesCount: Array.isArray(data.replies) ? data.replies.length : 0
    }));
  });
}

listLatestTwoFeedback().catch(console.error);
