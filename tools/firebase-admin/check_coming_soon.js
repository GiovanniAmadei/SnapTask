const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function check() {
  const snapshot = await db.collection("coming_soon").get();
  console.log(`Found ${snapshot.size} items in coming_soon`);
  snapshot.forEach(doc => console.log(`- ${doc.data().title}`));
}

check().catch(console.error);
