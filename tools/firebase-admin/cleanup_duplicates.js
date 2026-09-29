const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function cleanup() {
  const snapshot = await db.collection("app_updates").where("version", "==", "1.4").get();
  console.log(`Found ${snapshot.size} items for version 1.4`);
  
  const seen = new Set();
  const batch = db.batch();
  let deletedCount = 0;

  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const key = `${data.title}_${data.description}`;
    if (seen.has(key)) {
      batch.delete(doc.ref);
      deletedCount++;
      console.log(`- Deleting duplicate: ${data.title}`);
    } else {
      seen.add(key);
      console.log(`- Keeping: ${data.title}`);
    }
  });

  if (deletedCount > 0) {
    await batch.commit();
    console.log(`✅ Deleted ${deletedCount} duplicates for version 1.4`);
  } else {
    console.log("No duplicates found to delete.");
  }
}

cleanup().catch(console.error);
