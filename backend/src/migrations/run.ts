/**
 * Migration Runner
 *
 * Runs SQL migrations in order. Tracks applied migrations in a
 * schema_migrations table.
 */

import { pool, query } from '../config/database';
import fs from 'fs';
import path from 'path';

const MIGRATIONS_DIR = __dirname;

async function ensureMigrationsTable(): Promise<void> {
  await query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);
}

async function getAppliedMigrations(): Promise<Set<string>> {
  const { rows } = await query<{ version: string }>(
    'SELECT version FROM schema_migrations ORDER BY version'
  );
  return new Set(rows.map(r => r.version));
}

async function getMigrationFiles(): Promise<string[]> {
  const files = fs.readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort();
  return files;
}

function extractUpSection(sql: string): string {
  // Extract everything between "-- UP" and "-- DOWN" (or end of file)
  const upMatch = sql.match(/--\s*UP\s*\n([\s\S]*?)(?=--\s*DOWN|$)/i);
  if (upMatch) {
    return upMatch[1].trim();
  }
  // If no UP marker, use the whole file (excluding DOWN section)
  const downIndex = sql.indexOf('-- DOWN');
  if (downIndex > -1) {
    return sql.substring(0, downIndex).trim();
  }
  return sql.trim();
}

function extractDownSection(sql: string): string | null {
  const downMatch = sql.match(/--\s*DOWN\s*\n([\s\S]*?)$/i);
  if (downMatch) {
    // Remove comment markers from the down section
    return downMatch[1]
      .split('\n')
      .map(line => line.replace(/^--\s*/, ''))
      .join('\n')
      .trim();
  }
  return null;
}

async function runMigrations(): Promise<void> {
  console.log('Starting migrations...');

  await ensureMigrationsTable();
  const applied = await getAppliedMigrations();
  const files = await getMigrationFiles();

  let migrationsRun = 0;

  for (const file of files) {
    const version = file.replace('.sql', '');

    if (applied.has(version)) {
      console.log(`  [skip] ${version} (already applied)`);
      continue;
    }

    console.log(`  [run]  ${version}`);

    const filePath = path.join(MIGRATIONS_DIR, file);
    const sql = fs.readFileSync(filePath, 'utf-8');
    const upSql = extractUpSection(sql);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(upSql);
      await client.query(
        'INSERT INTO schema_migrations (version) VALUES ($1)',
        [version]
      );
      await client.query('COMMIT');
      migrationsRun++;
    } catch (error) {
      await client.query('ROLLBACK');
      console.error(`  [FAIL] ${version}:`, error);
      throw error;
    } finally {
      client.release();
    }
  }

  console.log(`Migrations complete. ${migrationsRun} migration(s) applied.`);
}

async function rollbackMigration(version?: string): Promise<void> {
  console.log('Rolling back migrations...');

  await ensureMigrationsTable();
  const applied = await getAppliedMigrations();

  if (applied.size === 0) {
    console.log('No migrations to rollback.');
    return;
  }

  // Get the last applied migration or specified version
  const versions = Array.from(applied).sort().reverse();
  const targetVersion = version || versions[0];

  if (!applied.has(targetVersion)) {
    console.log(`Migration ${targetVersion} not found or not applied.`);
    return;
  }

  console.log(`  [rollback] ${targetVersion}`);

  const filePath = path.join(MIGRATIONS_DIR, `${targetVersion}.sql`);
  const sql = fs.readFileSync(filePath, 'utf-8');
  const downSql = extractDownSection(sql);

  if (!downSql) {
    console.log('  [skip] No DOWN section found');
    return;
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(downSql);
    await client.query(
      'DELETE FROM schema_migrations WHERE version = $1',
      [targetVersion]
    );
    await client.query('COMMIT');
    console.log('Rollback complete.');
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Rollback failed:', error);
    throw error;
  } finally {
    client.release();
  }
}

// Main execution
const isRollback = process.argv.includes('down');

(async () => {
  try {
    if (isRollback) {
      const version = process.argv[3]; // Optional specific version
      await rollbackMigration(version);
    } else {
      await runMigrations();
    }
  } catch (error) {
    console.error('Migration error:', error);
    process.exit(1);
  } finally {
    await pool.end();
  }
})();
