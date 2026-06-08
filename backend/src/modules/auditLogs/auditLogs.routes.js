import { Router } from 'express';
import { getLogs, getLogUsers } from './auditLogs.controller.js';
import { authenticateToken, requireRole } from '../../middleware/auth.js';

const router = Router();

// Only administrators can view audit logs
router.use(authenticateToken);
router.use(requireRole('admin'));

router.get('/users', getLogUsers);
router.get('/', getLogs);

export default router;
