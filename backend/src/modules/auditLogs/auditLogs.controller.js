import { getAuditLogs, getDistinctLogUsers } from './auditLogs.model.js';

/**
 * Controller to fetch audit logs with pagination and filters.
 * Accessible only by administrators.
 */
export const getLogs = async (req, res) => {
  const { limit, offset, startDate, endDate, username, action, search } = req.query;
  try {
    const logs = await getAuditLogs({
      limit: limit ? parseInt(limit) : 20,
      offset: offset ? parseInt(offset) : 0,
      startDate,
      endDate,
      username,
      action,
      search
    });
    return res.status(200).json(logs);
  } catch (err) {
    console.error('Error fetching audit logs:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

/**
 * Controller to fetch all distinct users who have logs in the system.
 */
export const getLogUsers = async (req, res) => {
  try {
    const users = await getDistinctLogUsers();
    return res.status(200).json(users);
  } catch (err) {
    console.error('Error fetching distinct log users:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};
