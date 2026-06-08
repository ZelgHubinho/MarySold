import pool from '../../config/db.js';

export const getStats = async (req, res) => {
  let { startDate, endDate } = req.query;

  // Defaults: last 30 days
  const now = new Date();
  const defaultStartDate = new Date();
  defaultStartDate.setDate(now.getDate() - 30);
  defaultStartDate.setHours(0, 0, 0, 0);

  let start = defaultStartDate;
  if (startDate) {
    const parts = startDate.split('-');
    start = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]), 0, 0, 0, 0);
  }

  let end = now;
  if (endDate) {
    const parts = endDate.split('-');
    end = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]), 23, 59, 59, 999);
  }

  try {
    // 1. Overall Summary
    const summaryRes = await pool.query(
      `SELECT 
        COALESCE(SUM(total_amount), 0)::numeric(10, 2) as total_revenue, 
        COUNT(*)::integer as total_sales,
        COALESCE(AVG(total_amount), 0)::numeric(10, 2) as avg_sale_value
       FROM sales 
       WHERE created_at >= $1 AND created_at <= $2`,
      [start, end]
    );
    const summary = summaryRes.rows[0];

    // 2. Sales by Product Type
    const productsRes = await pool.query(
      `SELECT 
        COALESCE(i.type, 'Otros') as item_type, 
        SUM(si.quantity)::integer as quantity, 
        SUM(si.quantity * si.price)::numeric(10, 2) as revenue
       FROM sale_items si
       JOIN sales s ON si.sale_id = s.id
       LEFT JOIN items i ON si.item_id = i.id
       WHERE s.created_at >= $1 AND s.created_at <= $2
       GROUP BY item_type
       ORDER BY quantity DESC`,
      [start, end]
    );

    // 3. Hourly Distribution
    const hourlyRes = await pool.query(
      `SELECT 
        EXTRACT(HOUR FROM created_at)::integer as hour, 
        SUM(total_amount)::numeric(10, 2) as revenue,
        COUNT(*)::integer as sales_count
       FROM sales 
       WHERE created_at >= $1 AND created_at <= $2
       GROUP BY hour
       ORDER BY hour ASC`,
      [start, end]
    );

    // 4. Daily Trend
    const dailyRes = await pool.query(
      `SELECT 
        TO_CHAR(created_at, 'YYYY-MM-DD') as sale_date, 
        SUM(total_amount)::numeric(10, 2) as revenue
       FROM sales 
       WHERE created_at >= $1 AND created_at <= $2
       GROUP BY sale_date
       ORDER BY sale_date ASC`,
      [start, end]
    );

    return res.status(200).json({
      summary: {
        totalRevenue: parseFloat(summary.total_revenue),
        totalSales: parseInt(summary.total_sales),
        avgSaleValue: parseFloat(summary.avg_sale_value)
      },
      products: productsRes.rows.map(row => ({
        name: row.item_type,
        quantity: parseInt(row.quantity),
        revenue: parseFloat(row.revenue)
      })),
      hourly: hourlyRes.rows.map(row => ({
        hour: parseInt(row.hour),
        revenue: parseFloat(row.revenue),
        salesCount: parseInt(row.sales_count)
      })),
      daily: dailyRes.rows.map(row => ({
        date: row.sale_date,
        revenue: parseFloat(row.revenue)
      }))
    });
  } catch (err) {
    console.error('Error fetching sales statistics:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};
