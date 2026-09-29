const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function fetchAllFeedback() {
  const snapshot = await db.collection("feedback").get();
  const items = [];
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    
    let dateStr = "Unknown";
    if (data.creationDate && data.creationDate._seconds) {
      dateStr = new Date(data.creationDate._seconds * 1000).toISOString();
    } else if (data.submittedAt && data.submittedAt._seconds) {
      dateStr = new Date(data.submittedAt._seconds * 1000).toISOString();
    }

    items.push({
      docId: doc.id,
      id: data.id || doc.id,
      title: data.title || "(No Title)",
      description: data.description || "",
      category: data.category || "unknown",
      status: data.status || "pending",
      authorName: data.authorName || "Anonymous",
      authorId: data.authorId || null,
      votes: data.votes || 0,
      likes: data.likes || 0,
      date: dateStr,
      replies: (data.replies || []).map(r => ({
        authorName: r.authorName || "Anonymous",
        content: r.content,
        isFromDeveloper: r.isFromDeveloper || false,
        date: r.creationDate && r.creationDate._seconds ? new Date(r.creationDate._seconds * 1000).toISOString() : null
      })),
      developerReply: data.developerReply || null
    });
  });

  // Sort by date descending
  items.sort((a, b) => new Date(b.date) - new Date(a.date));

  const outputPath = "/Users/giovanni/Lavoro/iOS/SnapTask/tmp/all_feedback.json";
  fs.writeFileSync(outputPath, JSON.stringify(items, null, 2));
  console.log(`Saved ${items.length} feedback items to ${outputPath}`);
}

fetchAllFeedback().catch(console.error);
