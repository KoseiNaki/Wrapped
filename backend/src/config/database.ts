/**
 * Database Configuration
 *
 * Connects to Neon Postgres with connection pooling optimized for
 * Render free tier (limited connections, serverless-friendly).
 */

import { Pool, PoolConfig } from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const poolConfig: PoolConfig = {
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false,
  // Conservative pool settings for free tier
  max: 5,                    // Max connections in pool
  min: 1,                    // Min connections to keep open
  idleTimeoutMillis: 30000,  // Close idle connections after 30s
  connectionTimeoutMillis: 10000, // Connection timeout
  // Neon-specific: enable connection pooling mode
  application_name: 'wrapped-api',
};

export const pool = new Pool(poolConfig);

// Handle pool errors
pool.on('error', (err) => {
  console.error('Unexpected error on idle client', err);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, closing pool...');
  await pool.end();
  process.exit(0);
});

/**
 * Execute a query with automatic connection management
 */
export async function query<T = any>(text: string, params?: any[]): Promise<{ rows: T[]; rowCount: number }> {
  const start = Date.now();
  const result = await pool.query(text, params);
  const duration = Date.now() - start;

  if (duration > 100) {
    console.log(`Slow query (${duration}ms): ${text.substring(0, 100)}...`);
  }

  return { rows: result.rows as T[], rowCount: result.rowCount || 0 };
}

/**
 * Get a client for transaction support
 */
export async function getClient() {
  const client = await pool.connect();
  return client;
}

export default pool;
