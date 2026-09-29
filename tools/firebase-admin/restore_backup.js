const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function restore() {
  console.log("Removing all 1.5 and 1.6 updates I added...");
  const snapshot = await db.collection("app_updates")
    .where("version", "in", ["1.5", "1.6"])
    .get();
  
  const batch = db.batch();
  snapshot.forEach(doc => batch.delete(doc.ref));
  await batch.commit();
  console.log(`✅ Removed ${snapshot.size} documents`);
}

restore().catch(console.error);
