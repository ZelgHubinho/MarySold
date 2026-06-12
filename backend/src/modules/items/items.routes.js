import { Router } from 'express';
import { getItems, getItem, create, update, remove, checkout, getByBarcode, getPhotos } from './items.controller.js';
import { authenticateToken, requireRole } from '../../middleware/auth.js';
import upload from '../../middleware/upload.js';

const router = Router();

// All item endpoints require authentication
router.use(authenticateToken);

// Read endpoints (accessible by both admin and seller)
router.get('/', getItems);
router.get('/barcode/:barcode', requireRole(['admin', 'seller']), getByBarcode);
router.get('/:id', getItem);
router.get('/:id/photos', getPhotos);

// Checkout endpoint (accessible by both admin and seller)
router.post('/checkout', requireRole(['admin', 'seller']), checkout);

// Write endpoints (restricted to admin role)
router.post('/', requireRole('admin'), upload.array('photos', 5), create);
router.put('/:id', requireRole('admin'), upload.array('photos', 5), update);
router.delete('/:id', requireRole('admin'), remove);

export default router;
