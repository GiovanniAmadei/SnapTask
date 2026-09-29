const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function updateNewsToVersion17() {
  console.log("🚀 Starting update for app_updates (SnapTask 1.7)...");

  // 1. Fetch all documents in app_updates
  const snapshot = await db.collection("app_updates").get();
  console.log(`Currently found ${snapshot.size} documents in app_updates.`);

  const batch = db.batch();

  // 2. Remove obsolete coming_soon and roadmap items, and old beta versions (< 1.0)
  const obsoleteTitles = ["Widgets", "Expanded Calendar view", "Revamped Timeline"];
  const betaVersions = ["0.1.0", "0.2.0", "0.2.1", "0.3"];

  let deleteCount = 0;
  snapshot.docs.forEach((doc) => {
    const data = doc.data();

    // Check obsolete coming_soon or roadmap
    if ((data.type === "coming_soon" || data.type === "roadmap") && obsoleteTitles.includes(data.title)) {
      console.log(`🗑️ Deleting obsolete item: [${data.type}] "${data.title}" (${doc.id})`);
      batch.delete(doc.ref);
      deleteCount++;
    }

    // Check old beta versions
    if (data.type === "recent" && betaVersions.includes(data.version)) {
      console.log(`🗑️ Deleting old beta update: v${data.version} - "${data.title}" (${doc.id})`);
      batch.delete(doc.ref);
      deleteCount++;
    }

    // Check if any 1.7 item already exists to avoid duplicates
    if (data.version === "1.7") {
      console.log(`🗑️ Deleting existing 1.7 item to replace cleanly: "${data.title}" (${doc.id})`);
      batch.delete(doc.ref);
      deleteCount++;
    }
  });

  console.log(`Queued ${deleteCount} deletions.`);

  // 3. Define new Version 1.7 updates
  const baseDate = new Date("2026-09-03T12:00:00Z");
  const baseSeconds = Math.floor(baseDate.getTime() / 1000);

  const newV17Updates = [
    {
      version: "1.7",
      title: "Live Activities & Dynamic Island",
      description: "Track your active Pomodoro timer and focus sessions in real time right from your Lock Screen and Dynamic Island.",
      isHighlighted: true,
      type: "recent",
      date: new admin.firestore.Timestamp(baseSeconds, 700000000),
    },
    {
      version: "1.7",
      title: "Siri & App Shortcuts",
      description: "Capture tasks with your voice using Siri, trigger Quick Add with the Action button, and check your planned tasks for today anytime.",
      isHighlighted: true,
      type: "recent",
      date: new admin.firestore.Timestamp(baseSeconds, 600000000),
    },
    {
      version: "1.7",
      title: "Liquid Glass Design",
      description: "A fresh, modern aesthetic with translucent glass effects, refined depths, and smoother visuals across the entire app.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(baseSeconds, 500000000),
    },
    {
      version: "1.7",
      title: "Focus & Session History",
      description: "Review past focus sessions in a dedicated timeline, edit logged times and notes, and manage session conflicts seamlessly.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(baseSeconds, 400000000),
    },
    {
      version: "1.7",
      title: "Recurring Tasks & Celebrations",
      description: "Choose whether to edit a single occurrence or the whole series, and enjoy confetti animations on completed tasks.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(baseSeconds, 300000000),
    },
    {
      version: "1.7",
      title: "“Back to Today” in Calendar",
      description: "Jump back to the current date instantly with a single tap while browsing past or future dates in the calendar.",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(baseSeconds, 200000000),
    },
    {
      version: "1.7",
      title: "Bug fixes and improvements",
      description: "Fixed notification scheduling for recurring tasks, improved reward points deduction, widget optimizations, and general stability polish. Thanks for your feedback!",
      isHighlighted: false,
      type: "recent",
      date: new admin.firestore.Timestamp(baseSeconds, 100000000),
    },
  ];

  // 4. Add new Coming Soon item: Quick Inbox (check if already present)
  const hasInbox = snapshot.docs.some((d) => d.data().type === "coming_soon" && d.data().title === "Quick Inbox");
  if (!hasInbox) {
    const inboxRef = db.collection("app_updates").doc();
    batch.set(inboxRef, {
      title: "Quick Inbox",
      description: "A dedicated capture inbox to quickly jot down shopping items, loose thoughts, and ideas before scheduling them into tasks.",
      isHighlighted: true,
      type: "coming_soon",
      date: admin.firestore.Timestamp.now(),
    });
    console.log(`➕ Added coming_soon: "Quick Inbox"`);
  }

  // 5. Add Version 1.7 updates to batch
  for (const item of newV17Updates) {
    const docRef = db.collection("app_updates").doc();
    batch.set(docRef, item);
    console.log(`➕ Added v1.7 update: "${item.title}" (highlighted: ${item.isHighlighted})`);
  }

  // Commit batch
  await batch.commit();
  console.log("🎉 Successfully updated Firestore app_updates collection!");

  // Verify final count and summary
  const finalSnap = await db.collection("app_updates").get();
  console.log(`\n📊 Final total items in app_updates: ${finalSnap.size}`);

  const byVer = {};
  finalSnap.docs.forEach((d) => {
    const data = d.data();
    const key = data.type === "recent" ? `v${data.version}` : data.type;
    byVer[key] = (byVer[key] || 0) + 1;
  });
  console.log("Final distribution:", byVer);
}

updateNewsToVersion17().catch(console.error);
