import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { findByUsername, createUser, findById } from './auth.model.js';
import { logAction } from '../../middleware/auditLogger.js';

const JWT_SECRET = process.env.JWT_SECRET || 'marysold_jwt_secret_key_2026';

export const register = async (req, res) => {
  const { username, password, role } = req.body;

  if (!username || !password || !role) {
    return res.status(400).json({ error: 'Username, password and role are required.' });
  }

  if (!['admin', 'seller'].includes(role)) {
    return res.status(400).json({ error: 'Role must be either admin or seller.' });
  }

  try {
    const existingUser = await findByUsername(username);
    if (existingUser) {
      return res.status(409).json({ error: 'Username is already taken.' });
    }

    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    const newUser = await createUser(username, passwordHash, role);
    
    // Log the successful user registration
    await logAction(newUser.id, newUser.username, 'REGISTER', `Usuario registrado con éxito. Rol: ${newUser.role}`);
    
    return res.status(201).json(newUser);
  } catch (err) {
    console.error('Error during registration:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const login = async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'Username and password are required.' });
  }

  try {
    const user = await findByUsername(username);
    if (!user) {
      // Log failed login
      await logAction(null, username, 'LOGIN_FAILED', 'Intento de inicio de sesión fallido: usuario no existe.');
      return res.status(401).json({ error: 'Invalid username or password.' });
    }

    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      // Log failed login
      await logAction(user.id, user.username, 'LOGIN_FAILED', 'Intento de inicio de sesión fallido: contraseña incorrecta.');
      return res.status(401).json({ error: 'Invalid username or password.' });
    }

    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Log the successful login action
    await logAction(user.id, user.username, 'LOGIN', `Inicio de sesión exitoso. Rol: ${user.role}`);

    return res.status(200).json({
      token,
      user: {
        id: user.id,
        username: user.username,
        role: user.role
      }
    });
  } catch (err) {
    console.error('Error during login:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const getMe = async (req, res) => {
  try {
    const user = await findById(req.user.id);
    if (!user) {
      return res.status(404).json({ error: 'User not found.' });
    }
    return res.status(200).json(user);
  } catch (err) {
    console.error('Error in getMe:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};

export const logout = async (req, res) => {
  try {
    // Log the successful logout action
    await logAction(req.user.id, req.user.username, 'LOGOUT', 'Cierre de sesión exitoso.');
    return res.status(200).json({ message: 'Sesión cerrada con éxito.' });
  } catch (err) {
    console.error('Error during logout:', err);
    return res.status(500).json({ error: 'Internal server error.' });
  }
};
