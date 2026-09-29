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

async function updateFeedback() {
  const batch = db.batch();

  // Helper to set/update dev reply and status
  async function processDoc(docId, newStatus, replyContent = null) {
    const ref = db.collection("feedback").doc(docId);
    const doc = await ref.get();
    if (!doc.exists) {
      console.log(`❌ Document ${docId} not found`);
      return;
    }

    const data = doc.data();
    const updateData = { status: newStatus };

    if (replyContent) {
      let replies = data.replies || [];
      // Remove existing developer replies to replace with new one
      replies = replies.filter(r => !r.isFromDeveloper);
      replies.push(createDevReply(replyContent));
      updateData.replies = replies;
    }

    batch.update(ref, updateData);
    console.log(`✅ Queued update for ${docId}: status=${newStatus}, reply=${replyContent ? 'YES' : 'NO'}`);
  }

  // 1 - Expense breakdown visual bug (25F20CBB-DB63-4C44-90CC-601CDC362568)
  await processDoc("25F20CBB-DB63-4C44-90CC-601CDC362568", "completed", "Thanks for reporting this! We’ve fixed this issue in the latest update. Thank you for your feedback!");

  // 5 - Button text display (AB47C4CF-440D-4A37-988D-70B7476BD65D)
  await processDoc("AB47C4CF-440D-4A37-988D-70B7476BD65D", "completed", "Thanks for reporting this! We’ve fixed this issue in the latest update. Thank you for your feedback!");

  // 8 - Pie chart circle (D32F6A02-1FB9-4DEA-B31D-A4E6BA710643) -> Hide/Reject
  await processDoc("D32F6A02-1FB9-4DEA-B31D-A4E6BA710643", "rejected");

  // 9 - Apple calendar (B57A9962-90C5-47A5-9949-925B27965345)
  await processDoc("B57A9962-90C5-47A5-9949-925B27965345", "completed", "Thanks for reporting this! We’ve fixed this issue in the latest update. Thank you for your feedback!");

  // 10 - Al advice (28EB9A3A-490F-4DA1-A64C-5D0EEED00C92)
  await processDoc("28EB9A3A-490F-4DA1-A64C-5D0EEED00C92", "pending", "Thanks for the suggestion! We will consider this feature for future updates.");

  // 11 - Apple Watch (BD156431-8941-4138-AAC9-91850100A999) -> Hide/Reject
  await processDoc("BD156431-8941-4138-AAC9-91850100A999", "rejected");

  // 12 - Location (AF4CF15F-276E-480D-B171-D92AEBD5E844) -> Hide/Reject (Already in app)
  await processDoc("AF4CF15F-276E-480D-B171-D92AEBD5E844", "rejected");

  // 13 - Today’s tasks and habits (4906D82A-5A4E-402E-AADF-9B563F1FD9D6) -> Hide/Reject
  await processDoc("4906D82A-5A4E-402E-AADF-9B563F1FD9D6", "rejected");

  // 14 - Dragging habits (B708C59B-1A7A-4A3D-AF77-335F99880B13)
  await processDoc("B708C59B-1A7A-4A3D-AF77-335F99880B13", "pending", "Thanks for the suggestion! This is a highly requested feature, and we'll do our best to add it as soon as possible.");

  // 15 - Haptic feedback (9406B54A-688B-4066-839B-916AE0119959)
  await processDoc("9406B54A-688B-4066-839B-916AE0119959", "pending", "Thanks for the suggestion! We will consider this for future updates.");

  // 16 - Inbox (41E428E7-9A8F-4434-908E-3B14695AD0BF) -> Hide/Reject
  await processDoc("41E428E7-9A8F-4434-908E-3B14695AD0BF", "rejected");

  // 17 - Confetti celebration (2873ADA4-B7BE-46E3-99AB-217F419B6985)
  await processDoc("2873ADA4-B7BE-46E3-99AB-217F419B6985", "pending", "Thanks for the suggestion! We are working on adding an option in settings so you can enable confetti celebrations when completing tasks!");

  // 18 - Sync Apple health (D30995D0-04D6-411C-97E3-4F0956C80080) -> Hide/Reject
  await processDoc("D30995D0-04D6-411C-97E3-4F0956C80080", "rejected");

  // 20 - Insight (4E70E517-1176-40EF-AA69-88C62040FD46) -> Hide/Reject
  await processDoc("4E70E517-1176-40EF-AA69-88C62040FD46", "rejected");

  // 22 - Overdue (9915F5AF-F5F4-4FD5-87D7-E7642A68A5D0) -> Hide/Reject
  await processDoc("9915F5AF-F5F4-4FD5-87D7-E7642A68A5D0", "rejected");

  // 23 - Notifications (BA788D5F-35DA-4F53-BF21-CC8F64FC50BC) -> Hide/Reject
  await processDoc("BA788D5F-35DA-4F53-BF21-CC8F64FC50BC", "rejected");

  // 24 - Weather (962D65CD-E8B6-4E10-9C04-F75D730492DF) -> Hide/Reject
  await processDoc("962D65CD-E8B6-4E10-9C04-F75D730492DF", "rejected");

  // 25 - Planner (E0EF242F-3EB8-404C-AE0C-DA378E8B1452) -> Hide/Reject
  await processDoc("E0EF242F-3EB8-404C-AE0C-DA378E8B1452", "rejected");

  await batch.commit();
  console.log("🎉 All Firebase updates committed successfully!");
}

updateFeedback().catch(console.error);
