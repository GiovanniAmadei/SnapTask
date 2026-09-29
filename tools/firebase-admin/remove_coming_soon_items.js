const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function removeComingSoon() {
  const snapshot = await db.collection("coming_soon")
    .where("title", "in", ["Widgets", "Expanded Calendar view"])
    .get();

  const batch = db.batch();
  snapshot.forEach((doc) => {
    batch.delete(doc.ref);
    console.log(`[DELETE] ${doc.id}: ${doc.data().title}`);
  });
  await batch.commit();
  console.log(`Done. Deleted ${snapshot.size} coming_soon items.`);
}

removeComingSoon().catch(console.error);
