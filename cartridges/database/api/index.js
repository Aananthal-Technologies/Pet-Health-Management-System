import supabase from '../controller/supabase.js';

const db = {
  // ── WRITE ──────────────────────────────────────────────────

  async registerUser(name, age, pincode) {
    const { data, error } = await supabase.rpc('register_user', {
      p_name: name,
      p_age: Number(age),
      p_pincode: pincode,
    });
    if (error) throw error;
    return data;
  },

  async registerClinic(clinic) {
    const { data, error } = await supabase.rpc('register_clinic', {
      p_name: clinic.name,
      p_address: clinic.address || null,
      p_pincode: clinic.pincode,
      p_phone: clinic.phone || null,
      p_email: clinic.email || null,
    });
    if (error) throw error;
    return data;
  },

  async registerPet(ownerMasterId, pet, pincode) {
    const { data, error } = await supabase.rpc('register_pet', {
      p_owner_master_id: ownerMasterId,
      p_name: pet.name,
      p_species: pet.species,
      p_breed: pet.breed || null,
      p_age: pet.age ? Number(pet.age) : null,
      p_weight: pet.weight ? Number(pet.weight) : null,
      p_color: pet.color || null,
      p_medical_notes: pet.medical_notes || null,
      p_pincode: pincode,
    });
    if (error) throw error;
    return data;
  },

  async createAppointment(appt) {
    const { data, error } = await supabase.rpc('create_appointment', {
      p_user_master_id: appt.user_id,
      p_pet_master_id: appt.pet_id,
      p_clinic_master_id: appt.clinic_id,
      p_appointment_date: appt.appointment_date,
      p_reason: appt.reason || null,
      p_pincode: appt.pincode,
    });
    if (error) throw error;
    return data;
  },

  // ── READ (pincode tables only) ──────────────────────────────

  async getUserProfile(pincode, userMasterId) {
    const { data, error } = await supabase.rpc('get_user_profile', {
      p_pincode: pincode,
      p_user_master_id: userMasterId,
    });
    if (error) throw error;
    return data;
  },

  async getClinicProfile(pincode, clinicMasterId) {
    const { data, error } = await supabase.rpc('get_clinic_profile', {
      p_pincode: pincode,
      p_clinic_master_id: clinicMasterId,
    });
    if (error) throw error;
    return data;
  },

  async getPincodeSummary(pincode) {
    const { data, error } = await supabase.rpc('get_pincode_summary', {
      p_pincode: pincode,
    });
    if (error) throw error;
    return data;
  },
};

export default db;
