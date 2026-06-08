import pool from '../config/db.js';

/**
 * Logs an action performed by a user to the audit_logs table.
 * 
 * @param {number|null} userId - The ID of the user performing the action
 * @param {string} username - The username of the actor
 * @param {string} action - The action identifier (e.g. 'LOGIN', 'CREATE_ITEM', etc.)
 * @param {string} details - Detailed description of the action
 */
export const logAction = async (userId, username, action, details) => {
  try {
    await pool.query(
      'INSERT INTO audit_logs (user_id, username, action, details) VALUES ($1, $2, $3, $4)',
      [userId, username, action, details]
    );
  } catch (err) {
    console.error('Error saving audit log to database:', err);
  }
};
