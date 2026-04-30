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
  try {
    const passwordHash = await bcrypt.hash(password, 10);
    const clinicId = await db.registerClinic({ name, email, passwordHash, phone, address, pincode, licenseNumber, specialization, workingHours, description });
    const token = jwt.sign({ id: clinicId, type: 'clinic', pincode }, process.env.JWT_SECRET, { expiresIn: '7d' });
    res.status(201).json({ success: true, token, clinicId, pincode, name });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
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
    await db.updateAppointmentStatus(req.params.masterId, status, req.body.pincode);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.listen(PORT, () => console.log(`Clinic app  → http://localhost:${PORT}`));

export default app;
