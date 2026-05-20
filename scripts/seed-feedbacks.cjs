/**
 * Seeds reader feedback for every book in Firestore.
 *
 * Prerequisites:
 *   cd functions && npm install
 *   firebase login  (or set GOOGLE_APPLICATION_CREDENTIALS to a service account JSON)
 *
 * Usage (from BooqlyProject root):
 *   node scripts/seed-feedbacks.cjs
 *   node scripts/seed-feedbacks.cjs --dry-run
 *   node scripts/seed-feedbacks.cjs --force   # overwrite existing feedback docs
 */

const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

const REVIEWERS = [
  "Alex K.",
  "Jordan P.",
  "Morgan L.",
  "Riley S.",
  "Casey T.",
  "Sam D.",
  "Taylor N.",
  "Jamie W.",
];

const COMMENT_TEMPLATES = [
  "{title} is exactly what I needed — clear, engaging, and worth every page.",
  "I finished {title} faster than expected. {author} explains ideas in a way that sticks.",
  "Solid read. Some sections of {title} are dense, but the payoff is real.",
  "{title} changed how I think about {category}. Highly recommend for curious readers.",
  "Good book overall. {title} has a few slow chapters, but the core message lands well.",
  "One of the better {category} picks on Booqly. {title} deserves a spot on your shelf.",
];

function hashString(value) {
  let hash = 0;
  for (let i = 0; i < value.length; i++) {
    hash = (hash << 5) - hash + value.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}

function buildFeedbacksForBook(book) {
  const seed = hashString(book.id);
  const count = 5;
  const feedbacks = [];

  for (let i = 0; i < count; i++) {
    const reviewer = REVIEWERS[(seed + i) % REVIEWERS.length];
    const rating = 3 + ((seed + i * 7) % 3); // 3, 4, or 5
    const template = COMMENT_TEMPLATES[(seed + i) % COMMENT_TEMPLATES.length];
    const comment = template
      .replaceAll("{title}", book.title)
      .replaceAll("{author}", book.author)
      .replaceAll("{category}", book.category || "this genre");

    const daysAgo = 5 + i * 11 + (seed % 20);
    const createdAt = new Date();
    createdAt.setDate(createdAt.getDate() - daysAgo);

    feedbacks.push({
      id: `fb_${i + 1}`,
      data: {
        bookId: book.id,
        userName: reviewer,
        rating,
        comment,
        createdAt: admin.firestore.Timestamp.fromDate(createdAt),
      },
    });
  }

  return feedbacks;
}

async function main() {
  const dryRun = process.argv.includes("--dry-run");
  const force = process.argv.includes("--force");

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: process.env.FIREBASE_PROJECT_ID || "booqlyapp-83777",
    });
  }

  const db = admin.firestore();
  const booksSnap = await db.collection("books").get();

  if (booksSnap.empty) {
    console.error("No books found in Firestore. Add books before seeding feedback.");
    process.exit(1);
  }

  let booksProcessed = 0;
  let feedbacksWritten = 0;

  for (const bookDoc of booksSnap.docs) {
    const book = {
      id: bookDoc.id,
      title: bookDoc.get("title") || "Untitled",
      author: bookDoc.get("author") || "Unknown",
      category: bookDoc.get("category") || "General",
    };

    const feedbacks = buildFeedbacksForBook(book);
    const colRef = db.collection("books").doc(book.id).collection("feedbacks");

    const existing = await colRef.limit(1).get();
    if (!existing.empty && !force) {
      console.log(`Skip ${book.title} (${book.id}) — feedback already exists`);
      booksProcessed++;
      continue;
    }

    console.log(`${dryRun ? "[dry-run] " : ""}${book.title}: ${feedbacks.length} reviews`);

    if (!dryRun) {
      if (force && !existing.empty) {
        const all = await colRef.get();
        const batch = db.batch();
        all.docs.forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }

      const batch = db.batch();
      for (const fb of feedbacks) {
        batch.set(colRef.doc(fb.id), fb.data);
        feedbacksWritten++;
      }
      await batch.commit();
    } else {
      feedbacksWritten += feedbacks.length;
    }

    booksProcessed++;
  }

  console.log(
    `\nDone. Books: ${booksProcessed}, feedbacks ${dryRun ? "planned" : "written"}: ${feedbacksWritten}`,
  );
  if (dryRun) {
    console.log("Run without --dry-run to write to Firestore.");
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
