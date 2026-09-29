const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function updateWhatsCooking() {
  const updatesRef = db.collection("app_updates");
  
  // New updates for 1.5 and 1.6
  const newUpdates = [
    // Version 1.6
    {
      version: "1.6",
      title: "Finance Dashboard",
      description: "Track balance, income and expenses in one place, with budgets, alerts, goals and charts.",
      isHighlighted: true,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-03-09"))
    },
    {
      version: "1.6",
      title: "Finance Widgets",
      description: "Keep your balance and monthly overview on your Home Screen and open SnapTask faster with a tap.",
      isHighlighted: true,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-03-09"))
    },
    {
      version: "1.6",
      title: "Rewards, improved",
      description: "Smoother experience with more reliable points tracking and history.",
      isHighlighted: false,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-03-09"))
    },
    {
      version: "1.6",
      title: "Sync improvements",
      description: "More robust CloudKit sync, including better merging and initial upload (Rewards + Finance data/settings).",
      isHighlighted: false,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-03-09"))
    },
    {
      version: "1.6",
      title: "Bug fixes and improvements",
      description: "Improved cross-device sync reliability, general stability improvements, UI polish, and minor text and localisation refinements. Thanks for your feedback!",
      isHighlighted: false,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-03-09"))
    },
    // Version 1.5
    {
      version: "1.5",
      title: "Widgets are here",
      description: "Keep your key tasks at a glance and jump into SnapTask faster from your Home Screen.",
      isHighlighted: true,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-02-15"))
    },
    {
      version: "1.5",
      title: "Media timeline in Calendar",
      description: "Review notes, photos, and audio day by day in a complete calendar view, so you can find and revisit everything in context.",
      isHighlighted: true,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-02-15"))
    },
    {
      version: "1.5",
      title: "“Worth it” in the Journal",
      description: "Mark what felt meaningful and make reflections quicker to make every day count.",
      isHighlighted: false,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-02-15"))
    },
    {
      version: "1.5",
      title: "Recurring tasks, improved",
      description: "More control over recurring notifications plus a new heatmap to visualize your consistency.",
      isHighlighted: false,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-02-15"))
    },
    {
      version: "1.5",
      title: "Auto light/dark mode",
      description: "SnapTask now follows your system appearance automatically.",
      isHighlighted: false,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-02-15"))
    },
    {
      version: "1.5",
      title: "Bug fixes and improvements",
      description: "Improved notifications reliability and location accuracy. Fixed an issue affecting long-term recurring tasks. Minor text and localization improvements.",
      isHighlighted: false,
      type: "recent",
      date: admin.firestore.Timestamp.fromDate(new Date("2026-02-15"))
    }
  ];

  console.log("Updating app_updates collection...");
  const batch = db.batch();
  for (const update of newUpdates) {
    const docRef = updatesRef.doc();
    batch.set(docRef, update);
  }
  await batch.commit();
  console.log("✅ Added 1.5 and 1.6 updates.");

  // Clean coming_soon
  console.log("Cleaning coming_soon items...");
  const comingSoonSnapshot = await db.collection("coming_soon")
    .where("title", "in", ["Widgets", "Expanded Calendar view"])
    .get();
  
  const cleanBatch = db.batch();
  comingSoonSnapshot.forEach(doc => {
    cleanBatch.delete(doc.ref);
    console.log(`🗑️ Deleted coming_soon: ${doc.data().title}`);
  });
  await cleanBatch.commit();
  console.log("✅ Cleaned coming_soon.");
}

updateWhatsCooking().catch(console.error);
