import pool from '../../config/db.js';

/**
 * Retrieves audit logs from the database with pagination and dynamic filtering.
 * 
 * @param {Object} params Filter and pagination options
 * @returns {Promise<Array>} List of log records
 */
export const getAuditLogs = async ({ limit = 20, offset = 0, startDate, endDate, username, action, search } = {}) => {
  let query = 'SELECT id, user_id, username, action, details, created_at FROM audit_logs';
  const conditions = [];
  const values = [];

  if (startDate && !isNaN(Date.parse(startDate))) {
    values.push(new Date(startDate));
    conditions.push(`created_at >= $${values.length}`);
  }
  if (endDate && !isNaN(Date.parse(endDate))) {
    values.push(new Date(endDate));
    conditions.push(`created_at <= $${values.length}`);
  }
  if (username && username !== 'Todos') {
    values.push(username);
    conditions.push(`username = $${values.length}`);
  }
  if (action && action !== 'Todos') {
    values.push(action);
    conditions.push(`action = $${values.length}`);
  }
  if (search) {
    values.push(`%${search.toLowerCase()}%`);
    conditions.push(`(LOWER(username) LIKE $${values.length} OR LOWER(action) LIKE $${values.length} OR LOWER(details) LIKE $${values.length})`);
  }

  if (conditions.length > 0) {
    query += ' WHERE ' + conditions.join(' AND ');
  }

  query += ' ORDER BY created_at DESC';

  // Add limit
  values.push(limit);
  query += ` LIMIT $${values.length}`;
  
  // Add offset
  values.push(offset);
  query += ` OFFSET $${values.length}`;

  const { rows } = await pool.query(query, values);
  return rows;
};

/**
 * Retrieves all distinct usernames from audit logs.
 * 
 * @returns {Promise<Array<string>>} Distinct list of usernames
 */
export const getDistinctLogUsers = async () => {
  const query = 'SELECT DISTINCT username FROM audit_logs ORDER BY username ASC';
  const { rows } = await pool.query(query);
  return rows.map(row => row.username);
};
