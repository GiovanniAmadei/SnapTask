// Adds a developer reply to a suggestion and pushes a notification to its author.
//
// Usage:
//   node reply_and_notify.js --title "Apple calendar" --reply "Thanks! Coming in 1.8."
//   node reply_and_notify.js --id DE94BBFE-7F80-4135-92F8-A1252C0E49DC --reply "..."
//   node reply_and_notify.js --title "Apple calendar" --notify-only   (push for the latest dev reply)
//   add --dry-run to print what would happen without writing or pushing.
//
// Env: SERVICE_ACCOUNT_PATH (default: <repo>/tmp/firebase/serviceAccountKey.json, gitignored)
//      plus the APNS_* variables documented in apns.js.
//
// The app stores the author's APNs token in push_tokens/{authorId} once they have written
// feedback. Without a token (older app versions) the app still notices the reply by itself
// the next time it is opened or refreshed in background.

const admin = require("firebase-admin");
const crypto = require("crypto");
const path = require("path");
const { sendPush } = require("./apns");

const DEV_ID = "giovanni_amadei_dev_id";
const DEV_NAME = "Giovanni (Developer)";

function parseArgs(argv) {
  const args = { dryRun: false, notifyOnly: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--title") args.title = argv[++i];
    else if (a === "--id") args.id = argv[++i];
    else if (a === "--reply") args.reply = argv[++i];
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--notify-only") args.notifyOnly = true;
    else throw new Error(`Unknown argument: ${a}`);
  }
  if (!args.title && !args.id) throw new Error("Pass --title or --id");
  if (!args.reply && !args.notifyOnly) throw new Error("Pass --reply \"...\" (or --notify-only)");
  return args;
}

// Must match FeedbackReplyNotifier.replyKey on iOS.
function replyKey(feedbackId, content) {
  return crypto.createHash("sha256").update(`${feedbackId}\n${content}`, "utf8").digest("hex").slice(0, 32);
}

async function findFeedback(db, { id, title }) {
  if (id) {
    const doc = await db.collection("feedback").doc(id).get();
    if (!doc.exists) throw new Error(`No feedback with id ${id}`);
    return doc;
  }
  const snapshot = await db.collection("feedback").where("title", "==", title).get();
  if (snapshot.empty) throw new Error(`No feedback with title '${title}'`);
  if (snapshot.size > 1) {
    const ids = snapshot.docs.map((d) => d.id).join(", ");
    throw new Error(`Several feedback items titled '${title}': ${ids}. Use --id.`);
  }
  return snapshot.docs[0];
}

async function notifyAuthor(db, feedback, content, { dryRun }) {
  const authorId = feedback.authorId;
  if (!authorId) {
    console.log("[PUSH] Feedback has no author id: nothing to notify.");
    return;
  }
  const tokenDoc = await db.collection("push_tokens").doc(authorId).get();
  if (!tokenDoc.exists) {
    console.log("[PUSH] Author has no push token yet (older app version?): the app will notify on next open.");
    return;
  }
  const { token, environment, bundleId } = tokenDoc.data();
  const key = replyKey(feedback.id, content);
  const payload = {
    aps: {
      alert: {
        "title-loc-key": "feedback_reply_notification_title",
        subtitle: feedback.title,
        body: content,
      },
      sound: "default",
      "thread-id": "feedback_replies",
    },
    type: "feedback_reply",
    feedbackId: feedback.id,
    replyKey: key,
  };

  if (dryRun) {
    console.log(`[DRY RUN] Would push to ${environment} (${bundleId}):`, JSON.stringify(payload));
    return;
  }

  const result = await sendPush({ token, environment, topic: bundleId, payload, collapseId: key });
  if (result.status === 200) {
    console.log(`[PUSH] Delivered to APNs (${environment}).`);
  } else if (result.status === 410 || result.reason === "BadDeviceToken" || result.reason === "Unregistered") {
    console.log(`[PUSH] Token no longer valid (${result.reason}): removing it.`);
    await tokenDoc.ref.delete();
  } else {
    console.log(`[PUSH] APNs rejected the push: ${result.status} ${result.reason}`);
  }
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH
    || path.resolve(__dirname, "../../tmp/firebase/serviceAccountKey.json");
  admin.initializeApp({ credential: admin.credential.cert(require(serviceAccountPath)) });
  const db = admin.firestore();

  const doc = await findFeedback(db, args);
  const data = doc.data();
  const feedback = { id: data.id || doc.id, title: data.title, authorId: data.authorId };
  let content = args.reply;

  if (args.notifyOnly) {
    const devReplies = (data.replies || []).filter((r) => r.isFromDeveloper);
    const latest = devReplies[devReplies.length - 1];
    content = latest ? latest.content : data.developerReply;
    if (!content) throw new Error(`'${feedback.title}' has no developer reply to notify`);
  } else {
    const already = (data.replies || []).some((r) => r.isFromDeveloper && r.content === content);
    if (already) {
      console.log(`[OK] '${feedback.title}': this reply is already there, only notifying.`);
    } else if (args.dryRun) {
      console.log(`[DRY RUN] Would add reply to '${feedback.title}'.`);
    } else {
      await doc.ref.update({
        replies: admin.firestore.FieldValue.arrayUnion({
          id: crypto.randomUUID().toUpperCase(),
          content,
          authorId: DEV_ID,
          authorName: DEV_NAME,
          creationDate: admin.firestore.Timestamp.now(),
          isFromDeveloper: true,
          likes: 0,
        }),
      });
      console.log(`[WRITE] '${feedback.title}': developer reply added.`);
    }
  }

  await notifyAuthor(db, feedback, content, args);
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
