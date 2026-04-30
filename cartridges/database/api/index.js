import supabase, { supabaseService } from '../controller/supabase.js';

const db = {
  async registerUser({ name, email, passwordHash, phone, age, address, pincode }) {
    const { data, error } = await supabase.rpc('register_user', {
      p_name: name, p_email: email, p_password_hash: passwordHash,
      p_phone: phone || null, p_age: age ? Number(age) : null, p_address: address || null, p_pincode: pincode,
    });
    if (error) throw error;
    return data;
  },

  async registerClinic({ name, email, passwordHash, phone, address, pincode, licenseNumber, specialization, workingHours, description }) {
    const { data, error } = await supabase.rpc('register_clinic', {
      p_name: name, p_email: email, p_password_hash: passwordHash,
      p_phone: phone || null, p_address: address || null, p_pincode: pincode,
      p_license_number: licenseNumber || null, p_specialization: specialization || null,
      p_working_hours: workingHours || null, p_description: description || null,
    });
    if (error) throw error;
    return data;
  },

  async registerPet(ownerMasterId, pet, pincode) {
    const { data, error } = await supabase.rpc('register_pet', {
      p_owner_master_id:    ownerMasterId,
      p_name:               pet.name,
      p_species:            pet.species,
      p_breed:              pet.breed              || null,
      p_gender:             pet.gender             || null,
      p_age:                pet.age                ? Number(pet.age)    : null,
      p_weight:             pet.weight             ? Number(pet.weight) : null,
      p_color:              pet.color              || null,
      p_medical_notes:      pet.medical_notes      || null,
      p_vaccination_status: pet.vaccination_status || 'unknown',
      p_last_checkup_date:  pet.last_checkup_date  || null,
      p_pincode:            pincode,
    });
    if (error) throw error;
    return data;
  },

  async createAppointment({ user_id, pet_id, clinic_id, appointment_date, reason, notes, pincode }) {
    const { data, error } = await supabase.rpc('create_appointment', {
      p_user_master_id:   user_id,
      p_pet_master_id:    pet_id,
      p_clinic_master_id: clinic_id,
      p_appointment_date: appointment_date,
      p_reason:           reason || null,
      p_notes:            notes  || null,
      p_pincode:          pincode,
    });
    if (error) throw error;
    return data;
  },

  async getUserByEmail(email) {
    const { data, error } = await supabaseService.rpc('get_user_by_email', { p_email: email });
    if (error) throw error;
    return data;
  },

  async getClinicByEmail(email) {
    const { data, error } = await supabaseService.rpc('get_clinic_by_email', { p_email: email });
    if (error) throw error;
    return data;
  },

  async getUserProfile(pincode, userMasterId) {
    const { data, error } = await supabase.rpc('get_user_profile', {
      p_pincode: pincode, p_user_master_id: userMasterId,
    });
    if (error) throw error;
    return data;
  },

  async getClinicAppointments(clinicMasterId) {
    const { data, error } = await supabase.rpc('get_clinic_appointments', {
      p_clinic_master_id: clinicMasterId,
    });
    if (error) throw error;
    return data;
  },

  async getClinicsByPincode(userPincode, page = 1) {
    const { data, error } = await supabase.rpc('get_clinics_by_pincode', {
      p_user_pincode: userPincode, p_page: page, p_per_page: 6,
    });
    if (error) throw error;
    return data;
  },

  async updateAppointmentStatus(appointmentMasterId, clinicMasterId, status, pincode) {
    const { data, error } = await supabase.rpc('update_appointment_status', {
      p_appointment_master_id: appointmentMasterId,
      p_clinic_master_id:      clinicMasterId,
      p_status:                status,
      p_pincode:               pincode,
    });
    if (error) throw error;
    return data;
  },
};

export default db;
