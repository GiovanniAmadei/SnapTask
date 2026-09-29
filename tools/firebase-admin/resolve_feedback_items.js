const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

function createDevReply(content) {
  return {
    id: require("crypto").randomUUID(),
    content: content,
    authorId: "giovanni_amadei_dev_id",
    authorName: "Giovanni (Developer)",
    creationDate: admin.firestore.Timestamp.now(),
    isFromDeveloper: true,
    likes: 0
  };
}

const resolvedItems = [
  {
    docId: "A682B347-13A8-44D9-8803-3F7C9D1B0605",
    title: "Recurring Task notifications turn off after saving",
    reply: "Thanks for reporting this! We've resolved this issue in the latest update. Thank you for your feedback!"
  },
  {
    docId: "4B35180E-AA86-47B7-B9CA-243EAE443C9D",
    title: "Reward redemption does not deduct points",
    reply: "Thanks for reporting this! We've resolved this issue in the latest update. Thank you for your feedback!"
  },
  {
    docId: "9FBAFF4E-38B1-453E-82AE-08FB1A0177AC",
    title: "Recurrence Settings Display in Italian When App Is Set to English",
    reply: "Thanks for reporting this! We've resolved this localization issue in the latest update. Thank you for your feedback!"
  },
  {
    docId: "DC2AEAF9-B880-4D87-A806-F43866B112C1",
    title: "Notifications",
    reply: "Thanks for reporting this! We've resolved this notification issue in the latest update. Thank you for your feedback!"
  }
];

async function updateResolvedFeedback() {
  const batch = db.batch();

  for (const item of resolvedItems) {
    const ref = db.collection("feedback").doc(item.docId);
    const doc = await ref.get();
    if (!doc.exists) {
      console.log(`❌ Document ${item.docId} not found`);
      continue;
    }

    const data = doc.data();
    let replies = data.replies || [];
    // Remove existing developer replies to replace with the updated one
    replies = replies.filter(r => !r.isFromDeveloper);
    replies.push(createDevReply(item.reply));

    batch.update(ref, {
      status: "completed",
      replies: replies
    });
    console.log(`✅ Queued update for '${item.title}' (${item.docId}) -> status: completed`);
  }

  await batch.commit();
  console.log("🎉 Successfully updated all resolved feedback items in Firestore!");
}

updateResolvedFeedback().catch(console.error);
