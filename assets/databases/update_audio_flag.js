const Database = require('better-sqlite3');
const db = new Database('spanish_app.db');

// 1. Add column if not exists
try {
  db.prepare(`ALTER TABLE sentences ADD COLUMN audio BOOLEAN DEFAULT FALSE`).run();
  console.log("✅ Step 1: Column 'audio' added to 'sentences' table.");
} catch (e) {
  if (e.message.includes("duplicate column name")) {
    console.log("ℹ️ Step 1: Column 'audio' already exists. Skipping.");
  } else {
    throw e;
  }
}

// 2. Prepare SQL statements
const checkAudioStmt = db.prepare(`SELECT 1 FROM sentences_with_audio WHERE sentence_id = ? LIMIT 1`);
const updateAudioStmt = db.prepare(`UPDATE sentences SET audio = ? WHERE id = ?`);
console.log("✅ Step 2: SQL statements prepared.");

// 3. Fetch all sentence IDs
const sentences = db.prepare(`SELECT id FROM sentences`).all();
console.log(`📦 Step 3: Loaded ${sentences.length} sentences from the database.`);

let trueCount = 0;
let falseCount = 0;

console.log("🚀 Step 4: Starting to update each sentence...");

// 4. Start updating in a transaction
db.transaction(() => {
  for (let i = 0; i < sentences.length; i++) {
    const { id } = sentences[i];
    const hasAudio = !!checkAudioStmt.get(id);
    updateAudioStmt.run(hasAudio ? 1 : 0, id);

    if (hasAudio) {
      trueCount++;
      if (trueCount % 500 === 0) {
        console.log(`🟢 Updated ${trueCount} sentences WITH audio so far...`);
      }
    } else {
      falseCount++;
      if (falseCount % 500 === 0) {
        console.log(`🔴 Updated ${falseCount} sentences WITHOUT audio so far...`);
      }
    }

    // Log every 1000th processed row
    if ((i + 1) % 1000 === 0) {
      console.log(`📝 Processed ${i + 1}/${sentences.length} rows...`);
    }
  }
})();

console.log("✅ Step 5: Update complete.");
console.log(`🎉 Final result: ${trueCount} sentences WITH audio, ${falseCount} WITHOUT audio.`);

