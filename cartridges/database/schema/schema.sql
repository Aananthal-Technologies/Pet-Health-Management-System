-- ============================================================
-- PHMS SCHEMA v2
-- Master tables = write only (auth reads are the only exception)
-- Pincode tables = all operational reads/writes
-- ============================================================

-- ── MASTER TABLES ───────────────────────────────────────────

create table "mastertable-users" (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  email         text not null unique,
  password_hash text not null,
  phone         text,
  age           integer not null,
  address       text,
  pincode       text not null,
  created_at    timestamptz default now()
);

create table "mastertable-clinics" (
  id             uuid primary key default gen_random_uuid(),
  name           text not null,
  email          text not null unique,
  password_hash  text not null,
  phone          text,
  address        text,
  pincode        text not null,
  license_number text,
  specialization text,
  working_hours  text,
  description    text,
  created_at     timestamptz default now()
);

create table "mastertable-pets" (
  id                 uuid primary key default gen_random_uuid(),
  owner_id           uuid not null references "mastertable-users"(id) on delete cascade,
  name               text not null,
  species            text not null,
  breed              text,
  gender             text,
  age                integer,
  weight             numeric(5,2),
  color              text,
  medical_notes      text,
  vaccination_status text default 'unknown',
  last_checkup_date  date,
  pincode            text not null,
  created_at         timestamptz default now()
);

create table "mastertable-appointments" (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references "mastertable-users"(id) on delete cascade,
  pet_id           uuid not null references "mastertable-pets"(id) on delete cascade,
  clinic_id        uuid not null references "mastertable-clinics"(id) on delete cascade,
  appointment_date timestamptz not null,
  reason           text,
  notes            text,
  status           text default 'pending' check (status in ('pending','approved','rejected')),
  pincode          text not null,
  created_at       timestamptz default now()
);

alter table "mastertable-users"        disable row level security;
alter table "mastertable-pets"         disable row level security;
alter table "mastertable-clinics"      disable row level security;
alter table "mastertable-appointments" disable row level security;

-- ── RPC: register_user ──────────────────────────────────────
create or replace function register_user(
  p_name          text,
  p_email         text,
  p_password_hash text,
  p_phone         text,
  p_age           integer,
  p_address       text,
  p_pincode       text
)
returns uuid language plpgsql security definer as $$
declare
  master_id uuid;
  users_tbl text := p_pincode || '-users';
begin
  insert into "mastertable-users" (name, email, password_hash, phone, age, address, pincode)
  values (p_name, p_email, p_password_hash, p_phone, p_age, p_address, p_pincode)
  returning id into master_id;

  execute format('
    create table if not exists %I (
      id         uuid primary key default gen_random_uuid(),
      master_id  uuid not null references "mastertable-users"(id) on delete cascade,
      name       text not null,
      email      text not null,
      phone      text,
      age        integer not null,
      address    text,
      pincode    text not null,
      created_at timestamptz default now()
    )
  ', users_tbl);

  execute format(
    'insert into %I (master_id,name,email,phone,age,address,pincode)
     values (%L::uuid,%L,%L,%L,%L::integer,%L,%L)',
    users_tbl, master_id, p_name, p_email, p_phone, p_age, p_address, p_pincode
  );

  return master_id;
end;
$$;

-- ── RPC: register_clinic ────────────────────────────────────
create or replace function register_clinic(
  p_name           text,
  p_email          text,
  p_password_hash  text,
  p_phone          text,
  p_address        text,
  p_pincode        text,
  p_license_number text,
  p_specialization text,
  p_working_hours  text,
  p_description    text
)
returns uuid language plpgsql security definer as $$
declare
  master_id   uuid;
  clinics_tbl text := p_pincode || '-clinics';
begin
  insert into "mastertable-clinics"
    (name,email,password_hash,phone,address,pincode,license_number,specialization,working_hours,description)
  values
    (p_name,p_email,p_password_hash,p_phone,p_address,p_pincode,p_license_number,p_specialization,p_working_hours,p_description)
  returning id into master_id;

  execute format('
    create table if not exists %I (
      id             uuid primary key default gen_random_uuid(),
      master_id      uuid not null references "mastertable-clinics"(id) on delete cascade,
      name           text not null,
      email          text not null,
      phone          text,
      address        text,
      pincode        text not null,
      license_number text,
      specialization text,
      working_hours  text,
      description    text,
      created_at     timestamptz default now()
    )
  ', clinics_tbl);

  execute format(
    'insert into %I (master_id,name,email,phone,address,pincode,license_number,specialization,working_hours,description)
     values (%L::uuid,%L,%L,%L,%L,%L,%L,%L,%L,%L)',
    clinics_tbl, master_id, p_name, p_email, p_phone, p_address, p_pincode,
    p_license_number, p_specialization, p_working_hours, p_description
  );

  return master_id;
end;
$$;

-- ── RPC: register_pet ───────────────────────────────────────
create or replace function register_pet(
  p_owner_master_id  uuid,
  p_name             text,
  p_species          text,
  p_breed            text,
  p_gender           text,
  p_age              integer,
  p_weight           numeric,
  p_color            text,
  p_medical_notes    text,
  p_vaccination_status text,
  p_last_checkup_date  date,
  p_pincode          text
)
returns uuid language plpgsql security definer as $$
declare
  master_id        uuid;
  pincode_owner_id uuid;
  users_tbl        text := p_pincode || '-users';
  pets_tbl         text := p_pincode || '-pets';
begin
  insert into "mastertable-pets"
    (owner_id,name,species,breed,gender,age,weight,color,medical_notes,vaccination_status,last_checkup_date,pincode)
  values
    (p_owner_master_id,p_name,p_species,p_breed,p_gender,p_age,p_weight,p_color,p_medical_notes,p_vaccination_status,p_last_checkup_date,p_pincode)
  returning id into master_id;

  execute format('select id from %I where master_id = %L', users_tbl, p_owner_master_id)
  into pincode_owner_id;

  execute format('
    create table if not exists %I (
      id                 uuid primary key default gen_random_uuid(),
      master_id          uuid not null references "mastertable-pets"(id) on delete cascade,
      owner_id           uuid not null references %I(id) on delete cascade,
      name               text not null,
      species            text not null,
      breed              text,
      gender             text,
      age                integer,
      weight             numeric(5,2),
      color              text,
      medical_notes      text,
      vaccination_status text,
      last_checkup_date  date,
      pincode            text not null,
      created_at         timestamptz default now()
    )
  ', pets_tbl, users_tbl);

  execute format(
    'insert into %I (master_id,owner_id,name,species,breed,gender,age,weight,color,medical_notes,vaccination_status,last_checkup_date,pincode)
     values (%L::uuid,%L::uuid,%L,%L,%L,%L,%L::integer,%L::numeric,%L,%L,%L,%L::date,%L)',
    pets_tbl, master_id, pincode_owner_id,
    p_name, p_species, p_breed, p_gender, p_age, p_weight, p_color,
    p_medical_notes, p_vaccination_status, p_last_checkup_date, p_pincode
  );

  return master_id;
end;
$$;

-- ── RPC: create_appointment ─────────────────────────────────
create or replace function create_appointment(
  p_user_master_id   uuid,
  p_pet_master_id    uuid,
  p_clinic_master_id uuid,
  p_appointment_date timestamptz,
  p_reason           text,
  p_notes            text,
  p_pincode          text
)
returns uuid language plpgsql security definer as $$
declare
  master_id          uuid;
  pincode_user_id    uuid;
  pincode_pet_id     uuid;
  pincode_clinic_id  uuid;
  clinic_rec         record;
  users_tbl          text := p_pincode || '-users';
  pets_tbl           text := p_pincode || '-pets';
  clinics_tbl        text := p_pincode || '-clinics';
  appointments_tbl   text := p_pincode || '-appointments';
begin
  insert into "mastertable-appointments"
    (user_id,pet_id,clinic_id,appointment_date,reason,notes,pincode)
  values
    (p_user_master_id,p_pet_master_id,p_clinic_master_id,p_appointment_date,p_reason,p_notes,p_pincode)
  returning id into master_id;

  execute format('select id from %I where master_id=%L', users_tbl, p_user_master_id) into pincode_user_id;
  execute format('select id from %I where master_id=%L', pets_tbl, p_pet_master_id)   into pincode_pet_id;

  execute format('
    create table if not exists %I (
      id         uuid primary key default gen_random_uuid(),
      master_id  uuid not null references "mastertable-clinics"(id) on delete cascade,
      name       text not null, email text, phone text, address text,
      pincode    text not null, license_number text, specialization text,
      working_hours text, description text, created_at timestamptz default now()
    )
  ', clinics_tbl);

  execute format('select id from %I where master_id=%L', clinics_tbl, p_clinic_master_id) into pincode_clinic_id;

  if pincode_clinic_id is null then
    select * from "mastertable-clinics" where id = p_clinic_master_id into clinic_rec;
    execute format(
      'insert into %I (master_id,name,email,phone,address,pincode,license_number,specialization,working_hours,description)
       values (%L::uuid,%L,%L,%L,%L,%L,%L,%L,%L,%L) returning id',
      clinics_tbl, p_clinic_master_id, clinic_rec.name, clinic_rec.email, clinic_rec.phone,
      clinic_rec.address, clinic_rec.pincode, clinic_rec.license_number,
      clinic_rec.specialization, clinic_rec.working_hours, clinic_rec.description
    ) into pincode_clinic_id;
  end if;

  execute format('
    create table if not exists %I (
      id               uuid primary key default gen_random_uuid(),
      master_id        uuid not null references "mastertable-appointments"(id) on delete cascade,
      user_id          uuid not null references %I(id) on delete cascade,
      pet_id           uuid not null references %I(id) on delete cascade,
      clinic_id        uuid not null references %I(id) on delete cascade,
      appointment_date timestamptz not null,
      reason           text,
      notes            text,
      status           text default ''pending'',
      pincode          text not null,
      created_at       timestamptz default now()
    )
  ', appointments_tbl, users_tbl, pets_tbl, clinics_tbl);

  execute format(
    'insert into %I (master_id,user_id,pet_id,clinic_id,appointment_date,reason,notes,pincode)
     values (%L::uuid,%L::uuid,%L::uuid,%L::uuid,%L::timestamptz,%L,%L,%L)',
    appointments_tbl, master_id,
    pincode_user_id, pincode_pet_id, pincode_clinic_id,
    p_appointment_date, p_reason, p_notes, p_pincode
  );

  return master_id;
end;
$$;

-- ── RPC: get_user_by_email (auth only — master read) ────────
create or replace function get_user_by_email(p_email text)
returns json language plpgsql security definer as $$
declare result json;
begin
  select row_to_json(u) from "mastertable-users" u where email = p_email into result;
  return result;
end;
$$;

-- ── RPC: get_clinic_by_email (auth only — master read) ──────
create or replace function get_clinic_by_email(p_email text)
returns json language plpgsql security definer as $$
declare result json;
begin
  select row_to_json(c) from "mastertable-clinics" c where email = p_email into result;
  return result;
end;
$$;

-- ── RPC: get_user_profile ───────────────────────────────────
create or replace function get_user_profile(p_pincode text, p_user_master_id uuid)
returns json language plpgsql security definer as $$
declare
  users_tbl        text := p_pincode || '-users';
  pets_tbl         text := p_pincode || '-pets';
  clinics_tbl      text := p_pincode || '-clinics';
  appointments_tbl text := p_pincode || '-appointments';
  result           json;
begin
  execute format('
    select json_build_object(
      ''user'', row_to_json(u),
      ''pets'', (select json_agg(p) from %I p where p.owner_id = u.id),
      ''appointments'', (
        select json_agg(json_build_object(
          ''appointment'', row_to_json(a),
          ''pet'',         row_to_json(p),
          ''clinic'',      row_to_json(c)
        ))
        from %I a
        join %I p on p.id = a.pet_id
        join %I c on c.id = a.clinic_id
        where a.user_id = u.id
        order by a.appointment_date desc
      )
    )
    from %I u where u.master_id = %L
  ', pets_tbl, appointments_tbl, pets_tbl, clinics_tbl, users_tbl, p_user_master_id)
  into result;
  return result;
end;
$$;

-- ── RPC: get_clinic_appointments ────────────────────────────
-- Reads from mastertable — acceptable for clinic admin operations
create or replace function get_clinic_appointments(p_clinic_master_id uuid)
returns json language plpgsql security definer as $$
declare result json;
begin
  select json_agg(json_build_object(
    'appointment', json_build_object(
      'id',               a.id,
      'appointment_date', a.appointment_date,
      'reason',           a.reason,
      'notes',            a.notes,
      'status',           a.status,
      'pincode',          a.pincode,
      'created_at',       a.created_at
    ),
    'user', json_build_object(
      'id',    u.id,
      'name',  u.name,
      'email', u.email,
      'phone', u.phone
    ),
    'pet', json_build_object(
      'id',      p.id,
      'name',    p.name,
      'species', p.species,
      'breed',   p.breed,
      'age',     p.age,
      'gender',  p.gender
    )
  ) order by a.appointment_date desc)
  from "mastertable-appointments" a
  join "mastertable-users" u on u.id = a.user_id
  join "mastertable-pets"  p on p.id = a.pet_id
  where a.clinic_id = p_clinic_master_id
  into result;
  return result;
end;
$$;

-- ── RPC: get_clinics_by_pincode ─────────────────────────────
create or replace function get_clinics_by_pincode(
  p_user_pincode text,
  p_page         integer default 1,
  p_per_page     integer default 6
)
returns json language plpgsql security definer as $$
declare
  result     json;
  offset_val integer := (p_page - 1) * p_per_page;
  prefix3    text    := left(p_user_pincode, 3);
  total      integer;
begin
  select count(*) from "mastertable-clinics" into total;

  select json_build_object(
    'clinics', json_agg(row_to_json(c)),
    'page',     p_page,
    'total',    total,
    'has_more', (offset_val + p_per_page) < total
  )
  from (
    select id,name,email,phone,address,pincode,specialization,working_hours,description
    from "mastertable-clinics"
    order by
      case when pincode = p_user_pincode        then 0
           when left(pincode,3) = prefix3       then 1
           else 2 end,
      name
    limit p_per_page offset offset_val
  ) c
  into result;

  return result;
end;
$$;

-- ── RPC: update_appointment_status ──────────────────────────
create or replace function update_appointment_status(
  p_appointment_master_id uuid,
  p_status                text,
  p_pincode               text
)
returns boolean language plpgsql security definer as $$
declare
  appointments_tbl text := p_pincode || '-appointments';
begin
  update "mastertable-appointments" set status = p_status where id = p_appointment_master_id;

  execute format(
    'update %I set status = %L where master_id = %L',
    appointments_tbl, p_status, p_appointment_master_id
  );

  return true;
end;
$$;

-- ── GRANTS ──────────────────────────────────────────────────
grant execute on function register_user(text,text,text,text,integer,text,text)                                                             to anon;
grant execute on function register_clinic(text,text,text,text,text,text,text,text,text,text)                                               to anon;
grant execute on function register_pet(uuid,text,text,text,text,integer,numeric,text,text,text,date,text)                                  to anon;
grant execute on function create_appointment(uuid,uuid,uuid,timestamptz,text,text,text)                                                    to anon;
grant execute on function get_user_by_email(text)                                                                                          to anon;
grant execute on function get_clinic_by_email(text)                                                                                        to anon;
grant execute on function get_user_profile(text,uuid)                                                                                      to anon;
grant execute on function get_clinic_appointments(uuid)                                                                                    to anon;
grant execute on function get_clinics_by_pincode(text,integer,integer)                                                                     to anon;
grant execute on function update_appointment_status(uuid,text,text)                                                                        to anon;
