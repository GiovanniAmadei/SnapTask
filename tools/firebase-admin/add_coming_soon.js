const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function add() {
  const batch = db.batch();
  
  const item1 = db.collection("coming_soon").doc();
  batch.set(item1, {
    title: "Expanded Calendar view",
    description: "A more powerful calendar screen to quickly browse past and upcoming tasks and preview attached media at a glance.",
    isHighlighted: false,
    type: "coming_soon",
    date: admin.firestore.Timestamp.fromDate(new Date("2025-12-02"))
  });
  
  const item2 = db.collection("coming_soon").doc();
  batch.set(item2, {
    title: "Widgets",
    description: "Home and Lock Screen widgets to check tasks and streaks faster, right from your device.",
    isHighlighted: true,
    type: "coming_soon",
    date: admin.firestore.Timestamp.fromDate(new Date("2025-12-02"))
  });
  
  await batch.commit();
  console.log("✅ Added 2 items to coming_soon");
}

add().catch(console.error);
