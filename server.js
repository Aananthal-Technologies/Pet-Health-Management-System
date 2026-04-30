import 'dotenv/config';
import express from 'express';
import path from 'path';
import { fileURLToPath } from 'url';
import db from './cartridges/database/api/index.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);

const app  = express();
const PORT = process.env.PORT || 3000;

app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(express.static(path.join(__dirname, 'static')));

app.get('/account/register', (_req, res) => {
  res.sendFile(path.join(__dirname, 'templates/account/register.html'));
});

app.post('/account/register', async (req, res) => {
  const { owner, pet } = req.body;
  try {
    const userId = await db.registerUser(owner.name, owner.age, owner.pincode);
    await db.registerPet(userId, pet, owner.pincode);
    res.status(201).json({ success: true, message: 'Registered successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post('/clinics/register', async (req, res) => {
  try {
    const id = await db.registerClinic(req.body);
    res.status(201).json({ success: true, message: 'Clinic registered successfully', id });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.post('/appointments/create', async (req, res) => {
  try {
    const id = await db.createAppointment(req.body);
    res.status(201).json({ success: true, message: 'Appointment created successfully', id });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/user/:pincode/:masterId',    async (req, res) => {
  try {
    const data = await db.getUserProfile(req.params.pincode, req.params.masterId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/clinic/:pincode/:masterId', async (req, res) => {
  try {
    const data = await db.getClinicProfile(req.params.pincode, req.params.masterId);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.get('/pincode/:pincode',          async (req, res) => {
  try {
    const data = await db.getPincodeSummary(req.params.pincode);
    res.json({ success: true, data });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

app.listen(PORT, () => {
  console.log(`http://localhost:${PORT}/account/register`);
});
