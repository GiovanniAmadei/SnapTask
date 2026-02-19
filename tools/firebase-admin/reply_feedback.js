const admin = require("firebase-admin");
const { randomUUID } = require("crypto");

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function normalize(s) {
  return (s ?? "").trim().toLowerCase();
}

async function main() {
  const serviceAccountPath = requireEnv("SERVICE_ACCOUNT_PATH");

  // Optional: set explicitly if you want to force a project.
  // Otherwise it will be inferred from the service account file.
  const projectId = process.env.FIREBASE_PROJECT_ID;

  const serviceAccount = require(serviceAccountPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    ...(projectId ? { projectId } : {}),
  });

  const db = admin.firestore();

  const updates = [
    {
      title: "Calendar Integration",
      replyContent:
        "Thanks a lot for the suggestion! We really appreciate it — we’ll work on this for the next update.",
    },
    {
      title: "Icons",
      replyContent: "Thanks for the suggestion! We’ve added more icons in the latest 1.5 update.",
    },
  ];

  const feedbackCollection = "feedback";

  for (const { title, replyContent } of updates) {
    const snapshot = await db
      .collection(feedbackCollection)
      .where("title", "==", title)
      .get();

    if (snapshot.empty) {
      console.log(`[SKIP] No feedback found with title == '${title}'`);
      continue;
    }

    for (const doc of snapshot.docs) {
      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(doc.ref);
        const data = fresh.data() || {};
        const replies = Array.isArray(data.replies) ? data.replies : [];

        const alreadyReplied = replies.some((r) => {
          const isFromDeveloper = Boolean(r?.isFromDeveloper);
          const content = normalize(r?.content);
          return isFromDeveloper && content === normalize(replyContent);
        });

        if (alreadyReplied) {
          console.log(`[OK] '${title}' (${doc.id}): developer reply already present`);
          return;
        }

        const replyData = {
          id: randomUUID(),
          content: replyContent,
          authorId: "giovanni_amadei_dev_id",
          authorName: "Giovanni (Developer)",
          creationDate: admin.firestore.Timestamp.now(),
          isFromDeveloper: true,
          likes: 0,
        };

        tx.update(doc.ref, {
          replies: admin.firestore.FieldValue.arrayUnion(replyData),
        });

        console.log(`[WRITE] '${title}' (${doc.id}): added developer reply`);
      });
    }
  }

  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
