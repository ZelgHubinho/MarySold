import fs from 'fs';
import path from 'path';
import { getAllItems, getItemById, createItem, updateItem, deleteItem, getItemsPaginated, getItemsCount } from './items.model.js';
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
  const { name, price, quantity, type } = req.body;

  if (!name || price === undefined || quantity === undefined) {
    if (req.file) {
      fs.unlink(req.file.path, () => {});
    }
    return res.status(400).json({ error: 'Name, price, and quantity are required.' });
  }

  const parsedPrice = parseFloat(price);
  const parsedQuantity = parseInt(quantity);

  if (isNaN(parsedPrice) || parsedPrice < 0) {
    if (req.file) fs.unlink(req.file.path, () => {});
    return res.status(400).json({ error: 'Price must be a positive number.' });
  }

  if (isNaN(parsedQuantity) || parsedQuantity < 0) {
    if (req.file) fs.unlink(req.file.path, () => {});
    return res.status(400).json({ error: 'Quantity must be a positive integer.' });
  }

  const photoUrl = req.file ? `/uploads/${req.file.filename}` : null;

  try {
    const newItem = await createItem(name, parsedPrice, parsedQuantity, type || 'Otros', photoUrl);

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
    if (req.file) {
      fs.unlink(req.file.path, () => {});
    }
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const update = async (req, res) => {
  const { id } = req.params;
  const { name, price, quantity, type } = req.body;

  try {
    const item = await getItemById(id);
    if (!item) {
      if (req.file) {
        fs.unlink(req.file.path, () => {});
      }
      return res.status(404).json({ error: 'Item not found.' });
    }

    const parsedPrice = price !== undefined ? parseFloat(price) : item.price;
    const parsedQuantity = quantity !== undefined ? parseInt(quantity) : item.quantity;

    if (isNaN(parsedPrice) || parsedPrice < 0) {
      if (req.file) fs.unlink(req.file.path, () => {});
      return res.status(400).json({ error: 'Price must be a positive number.' });
    }

    if (isNaN(parsedQuantity) || parsedQuantity < 0) {
      if (req.file) fs.unlink(req.file.path, () => {});
      return res.status(400).json({ error: 'Quantity must be a positive integer.' });
    }

    let photoUrl = item.photo_url;
    if (req.file) {
      photoUrl = `/uploads/${req.file.filename}`;
      if (item.photo_url) {
        const oldImagePath = path.join(process.cwd(), item.photo_url);
        fs.unlink(oldImagePath, (err) => {
          if (err && err.code !== 'ENOENT') {
            console.error(`Failed to delete old image file: ${oldImagePath}`, err);
          }
        });
      }
    }

    const updatedItem = await updateItem(
      id,
      name !== undefined ? name : item.name,
      parsedPrice,
      parsedQuantity,
      type !== undefined ? type : item.type,
      photoUrl
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
    if (req.file) {
      fs.unlink(req.file.path, () => {});
    }
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const remove = async (req, res) => {
  const { id } = req.params;
  try {
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
      const { id, quantity } = cartItem;

      if (!id || !quantity || quantity <= 0) {
        throw new Error('Datos de artículo inválidos en la solicitud.');
      }

      const itemRes = await client.query('SELECT * FROM items WHERE id = $1 FOR UPDATE', [id]);
      
      if (itemRes.rowCount === 0) {
        throw new Error(`El artículo con ID ${id} no existe.`);
      }

      const dbItem = itemRes.rows[0];

      if (dbItem.quantity < quantity) {
        throw new Error(`Stock insuficiente para "${dbItem.name}". Disponible: ${dbItem.quantity}, Solicitado: ${quantity}`);
      }

      await client.query('UPDATE items SET quantity = quantity - $1 WHERE id = $2', [quantity, id]);

      logDetailsItems.push(`${quantity}x ${dbItem.name} ($${dbItem.price})`);
      totalPrice += parseFloat(dbItem.price) * quantity;

      itemsToInsert.push({
        id: dbItem.id,
        name: dbItem.name,
        quantity: quantity,
        price: dbItem.price
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
        'INSERT INTO sale_items (sale_id, item_id, item_name, quantity, price) VALUES ($1, $2, $3, $4, $5)',
        [saleId, item.id, item.name, item.quantity, item.price]
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
