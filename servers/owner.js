import 'dotenv/config';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import db from '../cartridges/database/api/index.js';
import { verifyOwner } from '../middleware/auth.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);
const ROOT       = path.join(__dirname, '..');
const PORT       = process.env.OWNER_PORT || 3000;

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(ROOT, 'static')));

const html = (file) => path.join(ROOT, 'templates', 'owner', file);

app.get('/',          (_req, res) => res.sendFile(html('auth.html')));
app.get('/dashboard', (_req, res) => res.sendFile(html('dashboard.html')));

// ── Auth ────────────────────────────────────────────────────

app.post('/api/owner/register', async (req, res) => {
  const { name, email, password, phone, age, address, pincode, pet } = req.body;
  if (!name?.trim() || !email?.trim() || !password || !pincode?.trim() || !age) {
    return res.status(400).json({ success: false, message: 'Name, email, password, pincode and age are required' });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ success: false, message: 'Invalid email format' });
  }
  if (password.length < 6) {
    return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });
  }
  if (!/^\d{6}$/.test(pincode)) {
    return res.status(400).json({ success: false, message: 'Pincode must be 6 digits' });
  }
  try {
    const passwordHash = await bcrypt.hash(password, 10);
    const userId = await db.registerUser({ name: name.trim(), email: email.trim(), passwordHash, phone, age, address, pincode });
    if (pet?.name) await db.registerPet(userId, pet, pincode);
    const token = jwt.sign({ id: userId, type: 'owner', pincode }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({ success: true, token, userId, pincode, name: name.trim() });
  } catch (err) {
    console.error('[register owner]', err.message);
    res.status(400).json({ success: false, message: err.message.includes('duplicate') ? 'Email already registered' : 'Registration failed' });
  }
});

app.post('/api/owner/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const user = await db.getUserByEmail(email);
    if (!user) return res.status(401).json({ success: false, message: 'Invalid email or password' });
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return res.status(401).json({ success: false, message: 'Invalid email or password' });
    const token = jwt.sign({ id: user.id, type: 'owner', pincode: user.pincode }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.json({ success: true, token, userId: user.id, pincode: user.pincode, name: user.name });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── Profile ─────────────────────────────────────────────────

app.get('/api/owner/profile', verifyOwner, async (req, res) => {
  try {
    const data = await db.getUserProfile(req.user.pincode, req.user.id);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── Pets ────────────────────────────────────────────────────

app.post('/api/owner/pets', verifyOwner, async (req, res) => {
  try {
    const petId = await db.registerPet(req.user.id, req.body, req.user.pincode);
    res.status(201).json({ success: true, petId });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── Clinics discovery ────────────────────────────────────────

app.get('/api/owner/clinics', verifyOwner, async (req, res) => {
  try {
    const data = await db.getClinicsByPincode(req.user.pincode, Number(req.query.page) || 1);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── Appointments ─────────────────────────────────────────────

app.post('/api/owner/appointments', verifyOwner, async (req, res) => {
  const { pet_id, clinic_id, appointment_date, reason, notes } = req.body;
  try {
    const id = await db.createAppointment({
      user_id: req.user.id, pet_id, clinic_id,
      appointment_date, reason, notes, pincode: req.user.pincode,
    });
    res.status(201).json({ success: true, id });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.listen(PORT, () => console.log(`Owner app → http://localhost:${PORT}`));

export default app;
