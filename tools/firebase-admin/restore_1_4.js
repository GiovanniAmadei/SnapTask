const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function restore14() {
  const updates = [
    {
      version: "1.4",
      title: "Eisenhower Matrix",
      description: "A dedicated page lets you fine‑tune thresholds and priorities with intuitive controls so your Eisenhower Matrix matches how you work.",
      isHighlighted: true,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2025-11-20T00:00:00Z"))
    },
    {
      version: "1.4",
      title: "Bug fixes and improvements",
      description: "Rewards messages now always match the points you’ve earned. Tasks keep the exact day and time you set, and the Timeline only highlights what truly matters.",
      isHighlighted: false,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2025-11-20T00:00:00Z"))
    }
  ];

  const batch = db.batch();
  for (const update of updates) {
    const docRef = db.collection("app_updates").doc();
    batch.set(docRef, update);
  }
  await batch.commit();
  console.log("✅ Restored missing 1.4 cards");
}

restore14().catch(console.error);
