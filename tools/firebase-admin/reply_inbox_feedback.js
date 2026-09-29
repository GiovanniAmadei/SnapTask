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

async function replyToInboxFeedback() {
  const docId = "7CFB471C-9DB7-49CA-AB81-0E49B974D7E0";
  const ref = db.collection("feedback").doc(docId);
  const doc = await ref.get();

  if (!doc.exists) {
    console.error(`❌ Document ${docId} not found`);
    return;
  }

  const data = doc.data();
  let replies = data.replies || [];
  replies = replies.filter(r => !r.isFromDeveloper);
  const replyContent = "Thanks for the suggestion! We really appreciate your feedback and we will implement this in a future update.";
  replies.push(createDevReply(replyContent));

  await ref.update({
    replies: replies
  });

  console.log(`✅ Successfully replied to '${data.title}' (${docId})`);
}

replyToInboxFeedback().catch(console.error);
