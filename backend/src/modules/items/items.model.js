import pool from '../../config/db.js';

export const getAllItems = async () => {
  const result = await pool.query(`
    SELECT i.*, 
           COALESCE(
             (SELECT json_agg(json_build_object('id', v.id, 'size', v.size, 'quantity', v.quantity, 'barcode', v.barcode, 'price', v.price) ORDER BY v.size)
              FROM item_variants v 
              WHERE v.item_id = i.id), 
             '[]'::json
           ) as variants,
           COALESCE(
             (SELECT SUM(v.quantity) FROM item_variants v WHERE v.item_id = i.id),
             0
           )::int as quantity
    FROM items i 
    ORDER BY i.id DESC
  `);
  return result.rows;
};

export const getItemById = async (id) => {
  const result = await pool.query(`
    SELECT i.*, 
           COALESCE(
             (SELECT json_agg(json_build_object('id', v.id, 'size', v.size, 'quantity', v.quantity, 'barcode', v.barcode, 'price', v.price) ORDER BY v.size)
              FROM item_variants v 
              WHERE v.item_id = i.id), 
             '[]'::json
           ) as variants,
           COALESCE(
             (SELECT SUM(v.quantity) FROM item_variants v WHERE v.item_id = i.id),
             0
           )::int as quantity
    FROM items i 
    WHERE i.id = $1
  `, [id]);
  return result.rows[0];
};

export const getItemByBarcode = async (barcode) => {
  const result = await pool.query(`
    SELECT i.*, 
           COALESCE(
             (SELECT json_agg(json_build_object('id', v.id, 'size', v.size, 'quantity', v.quantity, 'barcode', v.barcode, 'price', v.price) ORDER BY v.size)
              FROM item_variants v 
              WHERE v.item_id = i.id), 
             '[]'::json
           ) as variants,
           COALESCE(
             (SELECT SUM(v.quantity) FROM item_variants v WHERE v.item_id = i.id),
             0
           )::int as quantity,
           v_match.id as matched_variant_id,
           v_match.size as matched_size
    FROM item_variants v_match
    JOIN items i ON v_match.item_id = i.id
    WHERE v_match.barcode = $1
  `, [barcode]);
  return result.rows[0];
};

const generateUniqueBarcode = async () => {
  let barcode;
  let exists = true;
  while (exists) {
    // Generate a unique 12-digit numeric code starting with 779
    const randomPart = Math.floor(100000000 + Math.random() * 900000000); // 9 digits
    barcode = `779${randomPart}`;
    const check = await pool.query('SELECT 1 FROM items WHERE barcode = $1', [barcode]);
    if (check.rowCount === 0) {
      exists = false;
    }
  }
  return barcode;
};

export const createItem = async (name, price, quantity, type, photoUrl, barcode, photoUrls = [], size = 'Única', gender = 'Unisex', variants = null) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      'INSERT INTO items (name, price, type, photo_url, gender) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [name, price, type || 'Otros', photoUrl, gender]
    );
    const item = result.rows[0];

    const finalVariants = (variants && variants.length > 0) ? variants : [
      { size: size || 'Única', quantity: quantity || 0, barcode: barcode }
    ];

    for (const variant of finalVariants) {
      let vBarcode = variant.barcode;
      if (!vBarcode || vBarcode.trim() === '') {
        vBarcode = await generateUniqueBarcode();
      }
      await client.query(
        'INSERT INTO item_variants (item_id, size, quantity, barcode, price) VALUES ($1, $2, $3, $4, $5)',
        [item.id, variant.size || 'Única', variant.quantity || 0, vBarcode, variant.price !== undefined ? parseFloat(variant.price) : price]
      );
    }

    if (photoUrls && photoUrls.length > 0) {
      for (const url of photoUrls) {
        await client.query(
          'INSERT INTO item_photos (item_id, photo_url) VALUES ($1, $2)',
          [item.id, url]
        );
      }
    }
    await client.query('COMMIT');
    return item;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export const updateItem = async (id, name, price, quantity, type, photoUrl, barcode, photoUrls = null, size = 'Única', gender = 'Unisex', variants = null) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await client.query(
      'UPDATE items SET name = $1, price = $2, type = $3, photo_url = $4, gender = $5 WHERE id = $6 RETURNING *',
      [name, price, type, photoUrl, gender, id]
    );
    const item = result.rows[0];

    if (variants !== null) {
      await client.query('DELETE FROM item_variants WHERE item_id = $1', [id]);
      for (const variant of variants) {
        let vBarcode = variant.barcode;
        if (!vBarcode || vBarcode.trim() === '') {
          vBarcode = await generateUniqueBarcode();
        }
        await client.query(
          'INSERT INTO item_variants (item_id, size, quantity, barcode, price) VALUES ($1, $2, $3, $4, $5)',
          [id, variant.size || 'Única', variant.quantity || 0, vBarcode, variant.price !== undefined ? parseFloat(variant.price) : price]
        );
      }
    } else if (quantity !== undefined || barcode !== undefined || size !== undefined) {
      let vBarcode = barcode;
      if (!vBarcode || vBarcode.trim() === '') {
        vBarcode = await generateUniqueBarcode();
      }
      await client.query('DELETE FROM item_variants WHERE item_id = $1', [id]);
      await client.query(
        'INSERT INTO item_variants (item_id, size, quantity, barcode, price) VALUES ($1, $2, $3, $4, $5)',
        [id, size || 'Única', quantity || 0, vBarcode, price !== undefined ? parseFloat(price) : 0.00]
      );
    }
    
    if (photoUrls !== null) {
      await client.query('DELETE FROM item_photos WHERE item_id = $1', [id]);
      if (photoUrls.length > 0) {
        for (const url of photoUrls) {
          await client.query(
            'INSERT INTO item_photos (item_id, photo_url) VALUES ($1, $2)',
            [id, url]
          );
        }
      }
    }
    await client.query('COMMIT');
    return item;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export const deleteItem = async (id) => {
  const result = await pool.query('DELETE FROM items WHERE id = $1 RETURNING *', [id]);
  return result.rows[0];
};

export const getItemPhotos = async (itemId) => {
  const result = await pool.query('SELECT * FROM item_photos WHERE item_id = $1 ORDER BY id ASC', [itemId]);
  return result.rows;
};

export const getItemsPaginated = async (limit, offset) => {
  const result = await pool.query(`
    SELECT i.*, 
           COALESCE(
             (SELECT json_agg(json_build_object('id', v.id, 'size', v.size, 'quantity', v.quantity, 'barcode', v.barcode, 'price', v.price) ORDER BY v.size)
              FROM item_variants v 
              WHERE v.item_id = i.id), 
             '[]'::json
           ) as variants,
           COALESCE(
             (SELECT SUM(v.quantity) FROM item_variants v WHERE v.item_id = i.id),
             0
           )::int as quantity
    FROM items i 
    ORDER BY i.id DESC 
    LIMIT $1 OFFSET $2
  `, [limit, offset]);
  return result.rows;
};

export const getItemsCount = async () => {
  const result = await pool.query('SELECT COUNT(*) AS total FROM items');
  return parseInt(result.rows[0].total, 10);
};
