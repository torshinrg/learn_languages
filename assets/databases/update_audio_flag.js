// migrate_add_columns.js

/**
 * Usage:
 *   node migrate_add_columns.js /path/to/spanish_app.db
 */

const sqlite3 = require('sqlite3').verbose();
const path = require('path');

const dbFile = process.argv[2] || path.resolve(__dirname, 'spanish_app.db');

const db = new sqlite3.Database(dbFile, sqlite3.OPEN_READWRITE, (err) => {
  if (err) {
    console.error(`❌ Failed to open database at ${dbFile}:`, err.message);
    process.exit(1);
  }
  console.log(`✅ Opened database at ${dbFile}`);
});

db.serialize(() => {
  // Add translation column
  db.run(
    `ALTER TABLE words ADD COLUMN translation TEXT;`,
    (err) => {
      if (err && !/duplicate column name/.test(err.message)) {
        console.error('❌ Error adding translation column:', err.message);
      } else {
        console.log('✅ translation column added (or already exists)');
      }
    }
  );

  // Add sentence column
  db.run(
    `ALTER TABLE words ADD COLUMN sentence TEXT;`,
    (err) => {
      if (err && !/duplicate column name/.test(err.message)) {
        console.error('❌ Error adding sentence column:', err.message);
      } else {
        console.log('✅ sentence column added (or already exists)');
      }
    }
  );

  // Add type column, defaulting to 'normal'
  db.run(
    `ALTER TABLE words ADD COLUMN type TEXT NOT NULL DEFAULT 'normal';`,
    (err) => {
      if (err && !/duplicate column name/.test(err.message)) {
        console.error('❌ Error adding type column:', err.message);
      } else {
        console.log("✅ type column added (or already exists; default = 'normal')");
      }
    }
  );
});

db.close((err) => {
  if (err) {
    console.error('❌ Error closing database:', err.message);
  } else {
    console.log('🔒 Database closed');
  }
});
