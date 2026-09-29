const admin = require("firebase-admin");

const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function listFeedback() {
  const snapshot = await db.collection("feedback").get();
  console.log(`Found ${snapshot.size} feedback items:\n`);
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    console.log(`- "${data.title}" (${data.category || 'unknown'})`);
  });
}

listFeedback().catch(console.error);
