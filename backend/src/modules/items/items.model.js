import pool from '../../config/db.js';

export const getAllItems = async () => {
  const result = await pool.query('SELECT * FROM items ORDER BY id DESC');
  return result.rows;
};

export const getItemById = async (id) => {
  const result = await pool.query('SELECT * FROM items WHERE id = $1', [id]);
  return result.rows[0];
};

export const createItem = async (name, price, quantity, type, photoUrl) => {
  const result = await pool.query(
    'INSERT INTO items (name, price, quantity, type, photo_url) VALUES ($1, $2, $3, $4, $5) RETURNING *',
    [name, price, quantity, type, photoUrl]
  );
  return result.rows[0];
};

export const updateItem = async (id, name, price, quantity, type, photoUrl) => {
  const result = await pool.query(
    'UPDATE items SET name = $1, price = $2, quantity = $3, type = $4, photo_url = $5 WHERE id = $6 RETURNING *',
    [name, price, quantity, type, photoUrl, id]
  );
  return result.rows[0];
};

export const deleteItem = async (id) => {
  const result = await pool.query('DELETE FROM items WHERE id = $1 RETURNING *', [id]);
  return result.rows[0];
};
