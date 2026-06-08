import pool from '../../config/db.js';

export const getAllItems = async () => {
  const result = await pool.query('SELECT * FROM items ORDER BY id DESC');
  return result.rows;
};

export const getItemById = async (id) => {
  const result = await pool.query('SELECT * FROM items WHERE id = $1', [id]);
  return result.rows[0];
};

export const getItemByBarcode = async (barcode) => {
  const result = await pool.query('SELECT * FROM items WHERE barcode = $1', [barcode]);
  return result.rows[0];
};

const generateUniqueBarcode = async () => {
  let barcode;
  let exists = true;
  while (exists) {
    // Generate a unique 12-digit numeric code starting with 779
    const randomPart = Math.floor(100000000 + Math.random() * 900000000); // 9 digits
    barcode = `779${randomPart}`;
    const check = await pool.query('SELECT 1 FROM items WHERE barcode = $1', [barcode]);
    if (check.rowCount === 0) {
      exists = false;
    }
  }
  return barcode;
};

export const createItem = async (name, price, quantity, type, photoUrl, barcode) => {
  let finalBarcode = barcode;
  if (!finalBarcode || finalBarcode.trim() === '') {
    finalBarcode = await generateUniqueBarcode();
  }
  const result = await pool.query(
    'INSERT INTO items (name, price, quantity, type, photo_url, barcode) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
    [name, price, quantity, type, photoUrl, finalBarcode]
  );
  return result.rows[0];
};

export const updateItem = async (id, name, price, quantity, type, photoUrl, barcode) => {
  let finalBarcode = barcode;
  if (!finalBarcode || finalBarcode.trim() === '') {
    finalBarcode = await generateUniqueBarcode();
  }
  const result = await pool.query(
    'UPDATE items SET name = $1, price = $2, quantity = $3, type = $4, photo_url = $5, barcode = $6 WHERE id = $7 RETURNING *',
    [name, price, quantity, type, photoUrl, finalBarcode, id]
  );
  return result.rows[0];
};

export const deleteItem = async (id) => {
  const result = await pool.query('DELETE FROM items WHERE id = $1 RETURNING *', [id]);
  return result.rows[0];
};

export const getItemsPaginated = async (limit, offset) => {
  const result = await pool.query(
    'SELECT * FROM items ORDER BY id DESC LIMIT $1 OFFSET $2',
    [limit, offset]
  );
  return result.rows;
};

export const getItemsCount = async () => {
  const result = await pool.query('SELECT COUNT(*) AS total FROM items');
  return parseInt(result.rows[0].total, 10);
};
