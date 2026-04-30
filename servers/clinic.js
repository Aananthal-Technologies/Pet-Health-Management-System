import 'dotenv/config';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import db from '../cartridges/database/api/index.js';
import { verifyClinic } from '../middleware/auth.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);
const ROOT       = path.join(__dirname, '..');
const PORT       = process.env.CLINIC_PORT || 3001;

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(ROOT, 'static')));

const html = (file) => path.join(ROOT, 'templates', 'clinic', file);

app.get('/',          (_req, res) => res.sendFile(html('auth.html')));
app.get('/dashboard', (_req, res) => res.sendFile(html('dashboard.html')));

// ── Auth ────────────────────────────────────────────────────

app.post('/api/clinic/register', async (req, res) => {
  const { name, email, password, phone, address, pincode, licenseNumber, specialization, workingHours, description } = req.body;
  if (!name?.trim() || !email?.trim() || !password) {
    return res.status(400).json({ success: false, message: 'Name, email and password are required' });
  }
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ success: false, message: 'Invalid email format' });
  }
  if (password.length < 6) {
    return res.status(400).json({ success: false, message: 'Password must be at least 6 characters' });
  }
  if (!pincode?.trim() || !/^\d{6}$/.test(pincode)) {
    return res.status(400).json({ success: false, message: 'Pincode must be 6 digits' });
  }
  try {
    const passwordHash = await bcrypt.hash(password, 10);
    const clinicId = await db.registerClinic({ name: name.trim(), email: email.trim(), passwordHash, phone, address, pincode, licenseNumber, specialization, workingHours, description });
    const token = jwt.sign({ id: clinicId, type: 'clinic', pincode }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({ success: true, token, clinicId, pincode, name: name.trim() });
  } catch (err) {
    console.error('[register clinic]', err.message);
    res.status(400).json({ success: false, message: err.message.includes('duplicate') ? 'Email already registered' : 'Registration failed' });
  }
});

app.post('/api/clinic/login', async (req, res) => {
  const { email, password } = req.body;
  try {
    const clinic = await db.getClinicByEmail(email);
    if (!clinic) return res.status(401).json({ success: false, message: 'Invalid email or password' });
    const valid = await bcrypt.compare(password, clinic.password_hash);
    if (!valid) return res.status(401).json({ success: false, message: 'Invalid email or password' });
    const token = jwt.sign({ id: clinic.id, type: 'clinic', pincode: clinic.pincode }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.json({ success: true, token, clinicId: clinic.id, pincode: clinic.pincode, name: clinic.name });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// ── Appointments ─────────────────────────────────────────────

app.get('/api/clinic/appointments', verifyClinic, async (req, res) => {
  try {
    const data = await db.getClinicAppointments(req.user.id);
    res.json({ success: true, data: data || [] });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.patch('/api/clinic/appointments/:masterId/status', verifyClinic, async (req, res) => {
  const { status } = req.body;
  if (!['approved', 'rejected'].includes(status)) {
    return res.status(400).json({ success: false, message: 'Status must be approved or rejected' });
  }
  try {
    const updated = await db.updateAppointmentStatus(
      req.params.masterId,
      req.user.id,
      status,
      req.user.pincode,
    );
    if (!updated) return res.status(403).json({ success: false, message: 'Appointment not found or not owned by this clinic' });
    res.json({ success: true });
  } catch (err) {
    console.error('[update status]', err.message);
    res.status(500).json({ success: false, message: err.message });
  }
});

app.listen(PORT, () => console.log(`Clinic app  → http://localhost:${PORT}`));

export default app;
