const admin = require("firebase-admin");
const serviceAccount = require("/Users/giovanni/Lavoro/iOS/SnapTask/tmp/firebase/serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function verify() {
  const snapshot = await db.collection("app_updates").orderBy("version", "desc").get();
  console.log(`\n--- Current App Updates (${snapshot.size} total) ---`);
  
  const groups = {};
  snapshot.forEach(doc => {
    const data = doc.data();
    const v = data.version || "unknown";
    if (!groups[v]) groups[v] = [];
    groups[v].push(data.title);
  });

  Object.keys(groups).sort().reverse().forEach(v => {
    console.log(`Version ${v}:`);
    groups[v].forEach(title => console.log(`  - ${title}`));
  });
  console.log("-------------------------------------------\n");
}

verify().catch(console.error);
