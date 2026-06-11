/**
 * Copies title, author, coverUrl, category from books/{id} into
 * users/{uid}/library/{id} for every library entry.
 *
 * Usage (from BooqlyProject root, after firebase login):
 *   node scripts/backfill-library-metadata.cjs
 *   node scripts/backfill-library-metadata.cjs --uid YOUR_USER_ID
 *   node scripts/backfill-library-metadata.cjs --dry-run
 */

const path = require("path");
const admin = require(path.join(__dirname, "..", "functions", "node_modules", "firebase-admin"));

const dryRun = process.argv.includes("--dry-run");
const uidArg = process.argv.find((a) => a.startsWith("--uid="));
const singleUid = uidArg ? uidArg.split("=")[1] : null;

if (!admin.apps.length) {
  admin.initializeApp({
    projectId: "booqlyapp-83777",
  });
}

const db = admin.firestore();

function openLibraryCover(title) {
  if (!title || !title.trim()) return "";
  return `https://covers.openlibrary.org/b/title/${encodeURIComponent(title.trim())}-M.jpg`;
}

function pickCover(bookData, title) {
  const raw =
    bookData.coverUrl ||
    bookData.coverURL ||
    bookData.cover ||
    bookData.imageUrl ||
    bookData.thumbnail ||
    "";
  let url = String(raw).trim();
  if (url.startsWith("//")) url = `https:${url}`;
  if (url.startsWith("http://")) url = url.replace("http://", "https://");
  if (url) return url;
  return openLibraryCover(title);
}

async function backfillUser(uid) {
  const libSnap = await db.collection("users").doc(uid).collection("library").get();
  let updated = 0;

  for (const libDoc of libSnap.docs) {
    const bookId = libDoc.id;
    const libData = libDoc.data();
    const bookSnap = await db.collection("books").doc(bookId).get();
    const bookData = bookSnap.exists ? bookSnap.data() : {};

    const title = bookData.title || libData.title || bookId;
    const author = bookData.author || libData.author || "";
    const coverUrl = pickCover(bookData, title);
    const category = bookData.category || libData.category || "";

    const patch = {};
    if (title) patch.title = title;
    if (author) patch.author = author;
    if (coverUrl) patch.coverUrl = coverUrl;
    if (category) patch.category = category;

    if (Object.keys(patch).length === 0) continue;

    console.log(`  ${bookId}: coverUrl=${coverUrl || "(none)"}`);
    if (!dryRun) {
      await libDoc.ref.set(patch, { merge: true });
    }
    updated++;
  }

  return updated;
}

async function main() {
  console.log(dryRun ? "[DRY RUN]" : "[LIVE]", "Backfilling library metadata…");

  if (singleUid) {
    const n = await backfillUser(singleUid);
    console.log(`Done. Updated ${n} library docs for user ${singleUid}.`);
    return;
  }

  const usersSnap = await db.collection("users").get();
  let total = 0;
  for (const userDoc of usersSnap.docs) {
    console.log(`User ${userDoc.id}:`);
    total += await backfillUser(userDoc.id);
  }
  console.log(`Done. Updated ${total} library docs across ${usersSnap.size} users.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
