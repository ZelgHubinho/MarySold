import { Router } from 'express';
import { getStats } from './sales.controller.js';
import { authenticateToken, requireRole } from '../../middleware/auth.js';

const router = Router();

// Only admin users can query sales statistics
router.use(authenticateToken);
router.use(requireRole('admin'));

router.get('/stats', getStats);

export default router;
