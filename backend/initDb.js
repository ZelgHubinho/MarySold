import fs from 'fs';
import path from 'path';
import pg from 'pg';
import bcrypt from 'bcryptjs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const dockerComposePath = path.join(__dirname, '../docker-compose.yml');

async function run() {
  console.log('Reading database credentials from docker-compose.yml...');
  if (!fs.existsSync(dockerComposePath)) {
    console.error('Error: docker-compose.yml not found at ' + dockerComposePath);
    process.exit(1);
  }

  const composeContent = fs.readFileSync(dockerComposePath, 'utf8');
  
  const userMatch = composeContent.match(/POSTGRES_USER:\s*(\S+)/);
  const passwordMatch = composeContent.match(/POSTGRES_PASSWORD:\s*(\S+)/);
  const dbMatch = composeContent.match(/POSTGRES_DB:\s*(\S+)/);

  if (!userMatch || !passwordMatch || !dbMatch) {
    console.error('Error: Could not parse database credentials from docker-compose.yml');
    process.exit(1);
  }

  const dbUser = userMatch[1].trim();
  const dbPassword = passwordMatch[1].trim();
  const dbName = dbMatch[1].trim();

  console.log(`Parsed credentials from docker-compose.yml: User=${dbUser}, DB=${dbName}`);

  let activeUser = dbUser;
  let client = new pg.Client({
    host: 'localhost',
    port: 5432,
    user: dbUser,
    password: dbPassword,
    database: 'postgres'
  });

  try {
    console.log(`Attempting connection with user '${dbUser}'...`);
    await client.connect();
    console.log(`Connected successfully using user '${dbUser}'.`);
  } catch (err) {
    console.log(`Connection with user '${dbUser}' failed: ${err.message}`);
    console.log("Attempting fallback connection using superuser 'postgres' and the provided password...");
    
    activeUser = 'postgres';
    client = new pg.Client({
      host: 'localhost',
      port: 5432,
      user: 'postgres',
      password: dbPassword,
      database: 'postgres'
    });

    try {
      await client.connect();
      console.log("Connected successfully using user 'postgres'.");
    } catch (fallbackErr) {
      console.error('Failed to connect to PostgreSQL default database with both users:', fallbackErr.message);
      console.error('Please make sure your local PostgreSQL is running and the password in docker-compose.yml is correct.');
      process.exit(1);
    }
  }

  // Create marysold db if it doesn't exist
  try {
    const dbCheckRes = await client.query("SELECT 1 FROM pg_database WHERE datname = $1", [dbName]);
    if (dbCheckRes.rowCount === 0) {
      console.log(`Database '${dbName}' does not exist. Creating it...`);
      await client.query(`CREATE DATABASE ${dbName}`);
      console.log(`Database '${dbName}' created successfully.`);
    } else {
      console.log(`Database '${dbName}' already exists.`);
    }
  } catch (err) {
    console.error(`Failed to check or create database '${dbName}':`, err.message);
    process.exit(1);
  } finally {
    await client.end();
  }

  // Connect to the marysold database to create tables and seed
  console.log(`Connecting to database '${dbName}' as '${activeUser}'...`);
  const marysoldClient = new pg.Client({
    host: 'localhost',
    port: 5432,
    user: activeUser,
    password: dbPassword,
    database: dbName
  });

  try {
    await marysoldClient.connect();
    console.log(`Connected to '${dbName}' database.`);

    // Create users table
    console.log('Creating users table if not exists...');
    await marysoldClient.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(50) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        role VARCHAR(20) NOT NULL CHECK (role IN ('admin', 'seller'))
      );
    `);

    // Create items table
    console.log('Creating items table if not exists...');
    await marysoldClient.query(`
      CREATE TABLE IF NOT EXISTS items (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        price NUMERIC(10, 2) NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        type VARCHAR(50) NOT NULL DEFAULT 'Otros',
        photo_url VARCHAR(255)
      );
    `);

    // Migrate items table by adding type column if it doesn't exist yet
    console.log('Migrating items table to add type column if needed...');
    await marysoldClient.query(`
      ALTER TABLE items ADD COLUMN IF NOT EXISTS type VARCHAR(50) NOT NULL DEFAULT 'Otros';
    `);

    // Create audit_logs table
    console.log('Creating audit_logs table if not exists...');
    await marysoldClient.query(`
      CREATE TABLE IF NOT EXISTS audit_logs (
        id SERIAL PRIMARY KEY,
        user_id INTEGER,
        username VARCHAR(50) NOT NULL,
        action VARCHAR(100) NOT NULL,
        details TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Create indexes for audit_logs to optimize pagination and filtering
    console.log('Creating audit_logs indexes if they do not exist...');
    await marysoldClient.query('CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at_desc ON audit_logs (created_at DESC);');
    await marysoldClient.query('CREATE INDEX IF NOT EXISTS idx_audit_logs_username_created_at_desc ON audit_logs (username, created_at DESC);');
    await marysoldClient.query('CREATE INDEX IF NOT EXISTS idx_audit_logs_action_created_at_desc ON audit_logs (action, created_at DESC);');

    // Create sales table
    console.log('Creating sales table if not exists...');
    await marysoldClient.query(`
      CREATE TABLE IF NOT EXISTS sales (
        id SERIAL PRIMARY KEY,
        user_id INTEGER,
        username VARCHAR(50) NOT NULL,
        total_amount NUMERIC(10, 2) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Create sale_items table
    console.log('Creating sale_items table if not exists...');
    await marysoldClient.query(`
      CREATE TABLE IF NOT EXISTS sale_items (
        id SERIAL PRIMARY KEY,
        sale_id INTEGER REFERENCES sales(id) ON DELETE CASCADE,
        item_id INTEGER NOT NULL,
        item_name VARCHAR(100) NOT NULL,
        quantity INTEGER NOT NULL,
        price NUMERIC(10, 2) NOT NULL
      );
    `);

    // Migrate existing CHECKOUT audit logs to sales and sale_items tables
    const salesCountCheck = await marysoldClient.query('SELECT COUNT(*) FROM sales');
    if (parseInt(salesCountCheck.rows[0].count) === 0) {
      console.log('Migrating historical checkouts from audit_logs to structured sales tables...');
      const checkouts = await marysoldClient.query("SELECT * FROM audit_logs WHERE action = 'CHECKOUT' ORDER BY created_at ASC");
      
      for (const log of checkouts.rows) {
        const details = log.details;
        const totalMatch = details.match(/Venta finalizada por valor de \$([0-9.]+)/);
        if (!totalMatch) continue;
        const totalAmount = parseFloat(totalMatch[1]);
        
        const saleRes = await marysoldClient.query(
          "INSERT INTO sales (user_id, username, total_amount, created_at) VALUES ($1, $2, $3, $4) RETURNING id",
          [log.user_id, log.username, totalAmount, log.created_at]
        );
        const saleId = saleRes.rows[0].id;
        
        const itemsMatch = details.match(/Ítems: \[(.+)\]/);
        if (itemsMatch) {
          const itemsStr = itemsMatch[1];
          const itemsArr = itemsStr.split(/,\s*(?=\d+x)/);
          for (const itemStr of itemsArr) {
            const itemMatch = itemStr.match(/(\d+)x (.+?) \(\$([0-9.]+)\)/);
            if (itemMatch) {
              const qty = parseInt(itemMatch[1]);
              const name = itemMatch[2].trim();
              const price = parseFloat(itemMatch[3]);
              
              const itemDbRes = await marysoldClient.query("SELECT id FROM items WHERE name = $1", [name]);
              const itemId = itemDbRes.rowCount > 0 ? itemDbRes.rows[0].id : 0;
              
              await marysoldClient.query(
                "INSERT INTO sale_items (sale_id, item_id, item_name, quantity, price) VALUES ($1, $2, $3, $4, $5)",
                [saleId, itemId, name, qty, price]
              );
            }
          }
        }
      }
      console.log(`Successfully migrated ${checkouts.rowCount} historical sales.`);
    }

    // Seed default users if they don't exist
    const adminCheck = await marysoldClient.query("SELECT * FROM users WHERE username = $1", ['admin']);
    if (adminCheck.rowCount === 0) {
      console.log('Seeding admin user...');
      const adminPassHash = await bcrypt.hash('admin123', 10);
      await marysoldClient.query(
        "INSERT INTO users (username, password_hash, role) VALUES ($1, $2, $3)",
        ['admin', adminPassHash, 'admin']
      );
      console.log('Admin user seeded (username: admin, password: admin123).');
    }

    const sellerCheck = await marysoldClient.query("SELECT * FROM users WHERE username = $1", ['seller']);
    if (sellerCheck.rowCount === 0) {
      console.log('Seeding seller user...');
      const sellerPassHash = await bcrypt.hash('seller123', 10);
      await marysoldClient.query(
        "INSERT INTO users (username, password_hash, role) VALUES ($1, $2, $3)",
        ['seller', sellerPassHash, 'seller']
      );
      console.log('Seller user seeded (username: seller, password: seller123).');
    }

    console.log('Database initialization and seeding completed successfully!');
  } catch (err) {
    console.error('Failed to configure database tables:', err);
    process.exit(1);
  } finally {
    await marysoldClient.end();
  }

  // Write .env file
  console.log('Generating .env file...');
  const envContent = `PORT=3000
DB_HOST=localhost
DB_PORT=5432
DB_USER=${activeUser}
DB_PASSWORD=${dbPassword}
DB_NAME=${dbName}
JWT_SECRET=marysold_jwt_secret_key_2026
`;
  fs.writeFileSync(path.join(__dirname, '.env'), envContent);
  console.log('.env file written successfully.');
}

run();
