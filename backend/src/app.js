import express from 'express';
import cors from 'cors';
import path from 'path';
import authRoutes from './modules/auth/auth.routes.js';
import itemsRoutes from './modules/items/items.routes.js';
import auditLogsRoutes from './modules/auditLogs/auditLogs.routes.js';
import salesRoutes from './modules/sales/sales.routes.js';

const app = express();

// Global Middlewares
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve uploaded item images statically
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/items', itemsRoutes);
app.use('/api/audit-logs', auditLogsRoutes);
app.use('/api/sales', salesRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date() });
});

// Centralized error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err.message || err);
  res.status(err.status || 500).json({
    error: err.message || 'An internal server error occurred.'
  });
});

export default app;
