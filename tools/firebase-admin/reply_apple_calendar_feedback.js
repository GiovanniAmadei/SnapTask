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

async function replyToAppleCalendarFeedback() {
  const docId = "DE94BBFE-7F80-4135-92F8-A1252C0E49DC";
  const ref = db.collection("feedback").doc(docId);
  const doc = await ref.get();

  if (!doc.exists) {
    console.error(`❌ Document ${docId} not found`);
    return;
  }

  const data = doc.data();
  let replies = data.replies || [];
  replies = replies.filter(r => !r.isFromDeveloper);
  const replyContent = "Thanks for the great suggestion! We really appreciate your feedback and we'll be adding support for displaying birthdays, holidays, and Apple Calendar events in the next update.";
  replies.push(createDevReply(replyContent));

  await ref.update({
    replies: replies
  });

  console.log(`✅ Successfully replied to '${data.title}' (${docId})`);
}

replyToAppleCalendarFeedback().catch(console.error);
