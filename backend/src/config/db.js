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

// Run database migrations on start to ensure barcode, size, gender columns, item_photos, and item_variants exist
pool.query('ALTER TABLE items ADD COLUMN IF NOT EXISTS barcode VARCHAR(100) UNIQUE;')
  .then(() => console.log('Database migration verified: barcode column is present.'))
  .catch((err) => console.error('Error verifying database migration for barcode column:', err));

pool.query(`
  ALTER TABLE items 
  ADD COLUMN IF NOT EXISTS size VARCHAR(50) NOT NULL DEFAULT 'Única',
  ADD COLUMN IF NOT EXISTS gender VARCHAR(50) NOT NULL DEFAULT 'Unisex';
`)
  .then(() => console.log('Database migration verified: size and gender columns are present.'))
  .catch((err) => console.error('Error verifying database migration for size and gender columns:', err));

pool.query(`
  CREATE TABLE IF NOT EXISTS item_photos (
    id SERIAL PRIMARY KEY,
    item_id INTEGER REFERENCES items(id) ON DELETE CASCADE,
    photo_url VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
`)
  .then(() => console.log('Database migration verified: item_photos table is present.'))
  .catch((err) => console.error('Error verifying database migration for item_photos table:', err));

pool.query(`
  CREATE TABLE IF NOT EXISTS item_variants (
    id SERIAL PRIMARY KEY,
    item_id INTEGER REFERENCES items(id) ON DELETE CASCADE,
    size VARCHAR(50) NOT NULL DEFAULT 'Única',
    quantity INTEGER NOT NULL DEFAULT 0,
    price NUMERIC(10, 2) NOT NULL DEFAULT 0.00,
    barcode VARCHAR(100) UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  CREATE INDEX IF NOT EXISTS idx_item_variants_item_id ON item_variants(item_id);
  CREATE INDEX IF NOT EXISTS idx_item_variants_barcode ON item_variants(barcode);
`)
  .then(() => {
    console.log('Database migration verified: item_variants table and indexes are present.');
    // Alter table to add price if it was created before without it
    return pool.query('ALTER TABLE item_variants ADD COLUMN IF NOT EXISTS price NUMERIC(10, 2) NOT NULL DEFAULT 0.00;');
  })
  .then(() => {
    // Update existing variants that have 0.00 price from parent items table
    return pool.query(`
      UPDATE item_variants iv
      SET price = COALESCE((SELECT price FROM items i WHERE i.id = iv.item_id), 0.00)
      WHERE iv.price = 0.00;
    `);
  })
  .then(() => {
    return pool.query('SELECT COUNT(*) FROM item_variants');
  })
  .then((res) => {
    if (parseInt(res.rows[0].count, 10) === 0) {
      console.log('Migrating existing items to item_variants...');
      return pool.query(`
        INSERT INTO item_variants (item_id, size, quantity, barcode, price)
        SELECT id, size, quantity, barcode, price FROM items
        ON CONFLICT (barcode) DO NOTHING;
      `);
    }
  })
  .then((res) => {
    if (res) {
      console.log('Successfully migrated existing items to item_variants.');
    }
  })
  .catch((err) => console.error('Error verifying database migration for item_variants:', err));

pool.query(`
  ALTER TABLE sale_items 
  ADD COLUMN IF NOT EXISTS size VARCHAR(50) DEFAULT 'Única',
  ADD COLUMN IF NOT EXISTS barcode VARCHAR(100);
`)
  .then(() => console.log('Database migration verified: sale_items size and barcode columns are present.'))
  .catch((err) => console.error('Error migrating sale_items table columns:', err));

export default pool;
