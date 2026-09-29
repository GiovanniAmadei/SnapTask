const admin = require("firebase-admin");

const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function readAllFeedback() {
  const snapshot = await db.collection("feedback").orderBy("votes", "desc").get();
  console.log(`\n📋 TOTALE FEEDBACK: ${snapshot.size}\n`);
  console.log("=".repeat(80));

  const bugs = [];
  const features = [];
  const general = [];

  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const item = { id: doc.id, ...data };
    if (data.category === "bug_report") bugs.push(item);
    else if (data.category === "feature_request") features.push(item);
    else general.push(item);
  });

  function printItem(item, index) {
    const date = item.creationDate?.toDate
      ? item.creationDate.toDate().toLocaleDateString("it-IT")
      : (item.creationDate ? new Date(item.creationDate).toLocaleDateString("it-IT") : "N/A");
    
    console.log(`\n[${index + 1}] 📌 TITOLO: ${item.title}`);
    console.log(`    📅 Data: ${date}`);
    console.log(`    👤 Autore: ${item.authorName || "Anonimo"}`);
    console.log(`    📊 Status: ${item.status || "pending"}`);
    console.log(`    👍 Voti: ${item.votes || 0}  ❤️ Likes: ${item.likes || 0}`);
    console.log(`    📝 Descrizione:\n       ${(item.description || "").replace(/\n/g, "\n       ")}`);
    
    if (item.replies && item.replies.length > 0) {
      console.log(`    💬 Risposte (${item.replies.length}):`);
      item.replies.forEach(reply => {
        const replyDate = reply.creationDate?.toDate
          ? reply.creationDate.toDate().toLocaleDateString("it-IT")
          : (reply.creationDate ? new Date(reply.creationDate).toLocaleDateString("it-IT") : "N/A");
        const who = reply.isFromDeveloper ? "🛠️ Dev" : `👤 ${reply.authorName || "Utente"}`;
        console.log(`       - ${who} (${replyDate}): ${reply.content}`);
      });
    }
    console.log("    " + "-".repeat(76));
  }

  // ---- BUG REPORTS ----
  console.log(`\n🐛 BUG REPORT (${bugs.length})`);
  console.log("=".repeat(80));
  bugs.forEach((item, i) => printItem(item, i));

  // ---- FEATURE REQUESTS ----
  console.log(`\n💡 FEATURE REQUEST (${features.length})`);
  console.log("=".repeat(80));
  features.forEach((item, i) => printItem(item, i));

  // ---- GENERAL FEEDBACK ----
  console.log(`\n💬 FEEDBACK GENERALE (${general.length})`);
  console.log("=".repeat(80));
  general.forEach((item, i) => printItem(item, i));

  console.log("\n✅ Fine lettura feedback.");
}

readAllFeedback().catch(console.error);
