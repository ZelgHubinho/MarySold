import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const pool = new pg.Pool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '5432'),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

pool.on('error', (err) => {
  console.error('Unexpected error on idle database client', err);
});

// Run database migrations on start to ensure barcode column exists
pool.query('ALTER TABLE items ADD COLUMN IF NOT EXISTS barcode VARCHAR(100) UNIQUE;')
  .then(() => console.log('Database migration verified: barcode column is present.'))
  .catch((err) => console.error('Error verifying database migration for barcode column:', err));

export default pool;
