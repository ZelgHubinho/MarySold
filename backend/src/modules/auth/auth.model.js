import pool from '../../config/db.js';

export const findByUsername = async (username) => {
  const result = await pool.query('SELECT * FROM users WHERE username = $1', [username]);
  return result.rows[0];
};

export const findById = async (id) => {
  const result = await pool.query('SELECT id, username, role FROM users WHERE id = $1', [id]);
  return result.rows[0];
};

export const createUser = async (username, passwordHash, role) => {
  const result = await pool.query(
    'INSERT INTO users (username, password_hash, role) VALUES ($1, $2, $3) RETURNING id, username, role',
    [username, passwordHash, role]
  );
  return result.rows[0];
};
