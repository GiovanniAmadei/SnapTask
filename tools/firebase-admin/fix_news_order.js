const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function fixUpdatesAndComingSoon() {
  // 1. Clear coming_soon collection
  console.log("Emptying coming_soon collection...");
  const csSnapshot = await db.collection("coming_soon").get();
  const csBatch = db.batch();
  csSnapshot.forEach(doc => csBatch.delete(doc.ref));
  await csBatch.commit();
  console.log("✅ coming_soon emptied.");

  // 2. Clear existing 1.5 and 1.6 updates to re-insert them in correct order
  console.log("Removing existing 1.5 and 1.6 updates...");
  const updatesSnapshot = await db.collection("app_updates")
    .where("version", "in", ["1.5", "1.6"])
    .get();
  const delBatch = db.batch();
  updatesSnapshot.forEach(doc => delBatch.delete(doc.ref));
  await delBatch.commit();
  console.log("✅ Old 1.5/1.6 updates removed.");

  // 3. Define new ordered updates
  // We use slightly different timestamps to ensure order if the app sorts by date
  const now = new Date();
  const date16 = admin.firestore.Timestamp.fromDate(new Date(now.getTime()));
  const date15 = admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 86400000 * 30)); // 30 days ago

  const orderedUpdates = [
    // Version 1.6 - Order: Finance Dashboard, Finance Widgets, Rewards, Sync, Bug fixes
    {
      version: "1.6",
      title: "Finance Dashboard",
      description: "Track balance, income and expenses in one place, with budgets, alerts, goals and charts.",
      isHighlighted: true,
      type: "recent",
      date: new admin.firestore.Timestamp(date16.seconds, 500000000)
    },
    {
      version: "1.6",
      title: "Finance Widgets",
      description: "Keep your balance and monthly overview on your Home Screen.",
      isHighlighted: true,
      type: "recent",
      date: new admin.firestore.Timestamp(date16.seconds, 400000000)
    },
    {
      version: "1.6",
      title: "Rewards, improved",
      description: "Smoother experience with more reliable points tracking and history.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(date16.seconds, 300000000)
    },
    {
      version: "1.6",
      title: "Sync improvements",
      description: "More robust CloudKit sync, including better merging and initial upload (Rewards + Finance data/settings).",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(date16.seconds, 200000000)
    },
    {
      version: "1.6",
      title: "Bug fixes and improvements",
      description: "Improved cross-device sync reliability, general stability improvements, UI polish, and minor text and localisation refinements. Thanks for your feedback!",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(date16.seconds, 100000000)
    },
    // Version 1.5 - Bug fixes as last
    {
      version: "1.5",
      title: "Widgets are here",
      description: "Keep your key tasks at a glance and jump into SnapTask faster from your Home Screen.",
      isHighlighted: true,
      type: "recent",
      date: new admin.firestore.Timestamp(date15.seconds, 500000000)
    },
    {
      version: "1.5",
      title: "Media timeline in Calendar",
      description: "Review notes, photos, and audio day by day in a complete calendar view, so you can find and revisit everything in context.",
      isHighlighted: true,
      type: "recent",
      date: new admin.firestore.Timestamp(date15.seconds, 400000000)
    },
    {
      version: "1.5",
      title: "“Worth it” in the Journal",
      description: "Mark what felt meaningful and make reflections quicker to make every day count.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(date15.seconds, 300000000)
    },
    {
      version: "1.5",
      title: "Recurring tasks, improved",
      description: "More control over recurring notifications plus a new heatmap to visualize your consistency.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(date15.seconds, 200000000)
    },
    {
      version: "1.5",
      title: "Auto light/dark mode",
      description: "SnapTask now follows your system appearance automatically.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(date15.seconds, 150000000)
    },
    {
      version: "1.5",
      title: "Bug fixes and improvements",
      description: "Improved notifications reliability and location accuracy. Fixed an issue affecting long-term recurring tasks. Minor text and localization improvements.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(date15.seconds, 100000000)
    }
  ];

  console.log("Inserting re-ordered updates...");
  const addBatch = db.batch();
  for (const update of orderedUpdates) {
    const docRef = db.collection("app_updates").doc();
    addBatch.set(docRef, update);
  }
  await addBatch.commit();
  console.log("✅ All updates re-inserted in order.");
}

fixUpdatesAndComingSoon().catch(console.error);
