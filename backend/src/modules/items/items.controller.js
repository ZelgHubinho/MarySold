import fs from 'fs';
import path from 'path';
import { getAllItems, getItemById, getItemByBarcode, createItem, updateItem, deleteItem, getItemsPaginated, getItemsCount, getItemPhotos } from './items.model.js';
import { logAction } from '../../middleware/auditLogger.js';
import pool from '../../config/db.js';

export const getItems = async (req, res) => {
  try {
    const page = parseInt(req.query.page);
    const limit = parseInt(req.query.limit);

    if (!isNaN(page) && !isNaN(limit) && page > 0 && limit > 0) {
      const offset = (page - 1) * limit;
      const items = await getItemsPaginated(limit, offset);
      const totalItems = await getItemsCount();
      return res.status(200).json({
        items,
        totalItems,
        page,
        limit,
        totalPages: Math.ceil(totalItems / limit)
      });
    } else {
      const items = await getAllItems();
      return res.status(200).json(items);
    }
  } catch (err) {
    console.error('Error fetching items:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const getItem = async (req, res) => {
  const { id } = req.params;
  try {
    const item = await getItemById(id);
    if (!item) {
      return res.status(404).json({ error: 'Item not found.' });
    }
    return res.status(200).json(item);
  } catch (err) {
    console.error('Error fetching item:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const create = async (req, res) => {
  const { name, price, quantity, type, barcode, size, gender, variants: variantsRaw } = req.body;
  let variants = null;
  if (variantsRaw) {
    try {
      variants = typeof variantsRaw === 'string' ? JSON.parse(variantsRaw) : variantsRaw;
    } catch (e) {
      console.error('Failed to parse variants JSON', e);
    }
  }

  if (!name || price === undefined || (quantity === undefined && (!variants || variants.length === 0))) {
    if (req.files) {
      req.files.forEach(file => fs.unlink(file.path, () => {}));
    }
    return res.status(400).json({ error: 'Name, price, and quantity (or variants) are required.' });
  }

  const parsedPrice = parseFloat(price);
  const parsedQuantity = quantity !== undefined ? parseInt(quantity) : 0;

  if (isNaN(parsedPrice) || parsedPrice < 0) {
    if (req.files) req.files.forEach(file => fs.unlink(file.path, () => {}));
    return res.status(400).json({ error: 'Price must be a positive number.' });
  }

  if (isNaN(parsedQuantity) || parsedQuantity < 0) {
    if (req.files) req.files.forEach(file => fs.unlink(file.path, () => {}));
    return res.status(400).json({ error: 'Quantity must be a positive integer.' });
  }

  const files = req.files || [];
  const photoUrl = files.length > 0 ? `/uploads/${files[0].filename}` : null;
  const secondaryPhotos = [];
  for (let i = 1; i < files.length; i++) {
    secondaryPhotos.push(`/uploads/${files[i].filename}`);
  }

  try {
    const newItem = await createItem(
      name,
      parsedPrice,
      parsedQuantity,
      type || 'Otros',
      photoUrl,
      barcode,
      secondaryPhotos,
      size || 'Única',
      gender || 'Unisex',
      variants
    );

    // Audit log
    await logAction(
      req.user.id,
      req.user.username,
      'CREATE_ITEM',
      `Artículo creado: "${name}" (ID: ${newItem.id}) con precio $${parsedPrice} y cantidad ${parsedQuantity}.`
    );

    return res.status(201).json(newItem);
  } catch (err) {
    console.error('Error creating item:', err);
    if (req.files) {
      req.files.forEach(file => fs.unlink(file.path, () => {}));
    }
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const update = async (req, res) => {
  const { id } = req.params;
  const { name, price, quantity, type, barcode, existingPhotos: existingPhotosRaw, size, gender, variants: variantsRaw } = req.body;
  let variants = null;
  if (variantsRaw) {
    try {
      variants = typeof variantsRaw === 'string' ? JSON.parse(variantsRaw) : variantsRaw;
    } catch (e) {
      console.error('Failed to parse variants JSON', e);
    }
  }

  try {
    const item = await getItemById(id);
    if (!item) {
      if (req.files) {
        req.files.forEach(file => fs.unlink(file.path, () => {}));
      }
      return res.status(404).json({ error: 'Item not found.' });
    }

    const parsedPrice = price !== undefined ? parseFloat(price) : item.price;
    const parsedQuantity = quantity !== undefined ? parseInt(quantity) : item.quantity;

    if (isNaN(parsedPrice) || parsedPrice < 0) {
      if (req.files) req.files.forEach(file => fs.unlink(file.path, () => {}));
      return res.status(400).json({ error: 'Price must be a positive number.' });
    }

    if (isNaN(parsedQuantity) || parsedQuantity < 0) {
      if (req.files) req.files.forEach(file => fs.unlink(file.path, () => {}));
      return res.status(400).json({ error: 'Quantity must be a positive integer.' });
    }

    let photoUrl = item.photo_url;
    let secondaryPhotos = null;

    if (existingPhotosRaw !== undefined) {
      let existingPhotos = [];
      if (existingPhotosRaw) {
        try {
          existingPhotos = JSON.parse(existingPhotosRaw);
        } catch (e) {
          if (Array.isArray(existingPhotosRaw)) {
            existingPhotos = existingPhotosRaw;
          } else {
            existingPhotos = [existingPhotosRaw];
          }
        }
      }

      // Fetch all old photos to see what was deleted
      const oldSecondary = await getItemPhotos(id);
      const oldPhotos = [];
      if (item.photo_url) oldPhotos.push(item.photo_url);
      oldSecondary.forEach(p => oldPhotos.push(p.photo_url));

      // Physically unlink deleted photos from disk
      for (const oldPhoto of oldPhotos) {
        if (!existingPhotos.includes(oldPhoto)) {
          const filePath = path.join(process.cwd(), oldPhoto);
          fs.unlink(filePath, (err) => {
            if (err && err.code !== 'ENOENT') {
              console.error(`Failed to delete removed image file: ${filePath}`, err);
            }
          });
        }
      }

      // Get new upload URLs
      const files = req.files || [];
      const newUploadUrls = files.map(file => `/uploads/${file.filename}`);

      // Combined photos: kept existing ones + new ones
      const combinedPhotos = [...existingPhotos, ...newUploadUrls];

      // Primary is combined[0], secondary is the rest
      photoUrl = combinedPhotos.length > 0 ? combinedPhotos[0] : null;
      secondaryPhotos = combinedPhotos.slice(1);
    } else {
      // Fallback behavior if existingPhotos is not sent
      const files = req.files || [];
      if (files.length > 0) {
        if (item.photo_url) {
          const oldImagePath = path.join(process.cwd(), item.photo_url);
          fs.unlink(oldImagePath, (err) => {
            if (err && err.code !== 'ENOENT') {
              console.error(`Failed to delete old image file: ${oldImagePath}`, err);
            }
          });
        }

        // Fetch and delete old secondary photo files
        const oldPhotos = await getItemPhotos(id);
        for (const oldPhoto of oldPhotos) {
          const oldImagePath = path.join(process.cwd(), oldPhoto.photo_url);
          fs.unlink(oldImagePath, (err) => {
            if (err && err.code !== 'ENOENT') {
              console.error(`Failed to delete old secondary image file: ${oldImagePath}`, err);
            }
          });
        }

        photoUrl = `/uploads/${files[0].filename}`;
        secondaryPhotos = [];
        for (let i = 1; i < files.length; i++) {
          secondaryPhotos.push(`/uploads/${files[i].filename}`);
        }
      }
    }

    const updatedItem = await updateItem(
      id,
      name !== undefined ? name : item.name,
      parsedPrice,
      parsedQuantity,
      type !== undefined ? type : item.type,
      photoUrl,
      barcode !== undefined ? barcode : item.barcode,
      secondaryPhotos,
      size !== undefined ? size : item.size,
      gender !== undefined ? gender : item.gender,
      variants
    );

    // Audit log
    await logAction(
      req.user.id,
      req.user.username,
      'UPDATE_ITEM',
      `Artículo modificado: "${updatedItem.name}" (ID: ${id}). Precio anterior: $${item.price} -> Nuevo: $${parsedPrice}. Stock anterior: ${item.quantity} -> Nuevo: ${parsedQuantity}.`
    );

    return res.status(200).json(updatedItem);
  } catch (err) {
    console.error('Error updating item:', err);
    if (req.files) {
      req.files.forEach(file => fs.unlink(file.path, () => {}));
    }
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const remove = async (req, res) => {
  const { id } = req.params;
  try {
    // Fetch secondary photo records before deleting the item from database (due to ON DELETE CASCADE)
    const oldPhotos = await getItemPhotos(id);

    const deletedItem = await deleteItem(id);
    if (!deletedItem) {
      return res.status(404).json({ error: 'Item not found.' });
    }

    if (deletedItem.photo_url) {
      const imagePath = path.join(process.cwd(), deletedItem.photo_url);
      fs.unlink(imagePath, (err) => {
        if (err && err.code !== 'ENOENT') {
          console.error(`Failed to delete image file: ${imagePath}`, err);
        }
      });
    }

    // Delete physical files for secondary photos
    for (const oldPhoto of oldPhotos) {
      const oldImagePath = path.join(process.cwd(), oldPhoto.photo_url);
      fs.unlink(oldImagePath, (err) => {
        if (err && err.code !== 'ENOENT') {
          console.error(`Failed to delete secondary image file: ${oldImagePath}`, err);
        }
      });
    }

    // Audit log
    await logAction(
      req.user.id,
      req.user.username,
      'DELETE_ITEM',
      `Artículo eliminado: "${deletedItem.name}" (ID: ${id}) con precio $${deletedItem.price} y cantidad ${deletedItem.quantity}.`
    );

    return res.status(200).json({ message: 'Item deleted successfully.', item: deletedItem });
  } catch (err) {
    console.error('Error deleting item:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const checkout = async (req, res) => {
  const { items } = req.body;

  if (!items || !Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'Debes enviar una lista de artículos para realizar el cobro.' });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const logDetailsItems = [];
    const itemsToInsert = [];
    let totalPrice = 0.0;

    for (const cartItem of items) {
      const { id, variantId, quantity } = cartItem;

      if (!id || !quantity || quantity <= 0) {
        throw new Error('Datos de artículo inválidos en la solicitud.');
      }

      let dbVariant;
      if (variantId) {
        const variantRes = await client.query('SELECT * FROM item_variants WHERE id = $1 FOR UPDATE', [variantId]);
        if (variantRes.rowCount === 0) {
          throw new Error(`La variante con ID ${variantId} no existe.`);
        }
        dbVariant = variantRes.rows[0];
      } else {
        const variantRes = await client.query('SELECT * FROM item_variants WHERE item_id = $1 ORDER BY id ASC LIMIT 1 FOR UPDATE', [id]);
        if (variantRes.rowCount === 0) {
          throw new Error(`El artículo con ID ${id} no tiene variantes registradas.`);
        }
        dbVariant = variantRes.rows[0];
      }

      const itemRes = await client.query('SELECT * FROM items WHERE id = $1', [dbVariant.item_id]);
      if (itemRes.rowCount === 0) {
        throw new Error(`El artículo con ID ${dbVariant.item_id} no existe.`);
      }
      const dbItem = itemRes.rows[0];

      if (dbVariant.quantity < quantity) {
        throw new Error(`Stock insuficiente para "${dbItem.name}" (Talla: ${dbVariant.size}). Disponible: ${dbVariant.quantity}, Solicitado: ${quantity}`);
      }

      await client.query('UPDATE item_variants SET quantity = quantity - $1 WHERE id = $2', [quantity, dbVariant.id]);

      const itemPrice = (dbVariant.price !== undefined && parseFloat(dbVariant.price) > 0) ? dbVariant.price : dbItem.price;

      logDetailsItems.push(`${quantity}x ${dbItem.name} (${dbVariant.size}) ($${itemPrice})`);
      totalPrice += parseFloat(itemPrice) * quantity;

      itemsToInsert.push({
        id: dbItem.id,
        name: dbItem.name,
        quantity: quantity,
        price: itemPrice,
        size: dbVariant.size,
        barcode: dbVariant.barcode
      });
    }

    // Insert structured sale record
    const saleRes = await client.query(
      'INSERT INTO sales (user_id, username, total_amount) VALUES ($1, $2, $3) RETURNING id',
      [req.user.id, req.user.username, totalPrice]
    );
    const saleId = saleRes.rows[0].id;

    // Insert structured sale items details
    for (const item of itemsToInsert) {
      await client.query(
        'INSERT INTO sale_items (sale_id, item_id, item_name, quantity, price, size, barcode) VALUES ($1, $2, $3, $4, $5, $6, $7)',
        [saleId, item.id, item.name, item.quantity, item.price, item.size, item.barcode]
      );
    }

    const detailsStr = `Venta finalizada por valor de $${totalPrice.toFixed(2)}. Ítems: [${logDetailsItems.join(', ')}].`;
    
    await client.query(
      'INSERT INTO audit_logs (user_id, username, action, details) VALUES ($1, $2, $3, $4)',
      [req.user.id, req.user.username, 'CHECKOUT', detailsStr]
    );

    await client.query('COMMIT');
    return res.status(200).json({ message: 'Venta completada con éxito.' });

  } catch (err) {
    await client.query('ROLLBACK');
    console.error('Error during checkout transaction:', err.message);
    return res.status(400).json({ error: err.message || 'Error al procesar la venta.' });
  } finally {
    client.release();
  }
};

export const getByBarcode = async (req, res) => {
  const { barcode } = req.params;
  try {
    const item = await getItemByBarcode(barcode);
    if (!item) {
      return res.status(404).json({ error: 'Artículo no encontrado con este código de barras.' });
    }
    return res.status(200).json(item);
  } catch (err) {
    console.error('Error fetching item by barcode:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const getPhotos = async (req, res) => {
  const { id } = req.params;
  try {
    const item = await getItemById(id);
    if (!item) {
      return res.status(404).json({ error: 'Item not found.' });
    }
    const photos = await getItemPhotos(id);
    return res.status(200).json(photos);
  } catch (err) {
    console.error('Error fetching item photos:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};
