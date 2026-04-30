-- ============================================================
-- PHMS DATABASE SCHEMA
-- Master tables = write only (insert / update)
-- Pincode tables = read / write, fully interlinked
-- ============================================================

-- ============================================================
-- CLEANUP
-- ============================================================
drop function if exists register_user(text, integer, text);
drop function if exists register_pet(uuid, text, text, text, integer, numeric, text, text, text);
drop function if exists register_clinic(text, text, text, text, text);
drop function if exists create_appointment(uuid, uuid, uuid, timestamptz, text, text);
drop function if exists get_user_profile(text, uuid);
drop function if exists get_clinic_profile(text, uuid);
drop function if exists get_pincode_summary(text);

drop table if exists "mastertable-appointments" cascade;
drop table if exists "mastertable-pets"         cascade;
drop table if exists "mastertable-clinics"      cascade;
drop table if exists "mastertable-users"        cascade;

-- ============================================================
-- MASTER TABLES  (write-only source of truth)
-- ============================================================

create table "mastertable-users" (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  age        integer not null,
  pincode    text not null,
  created_at timestamptz default now()
);

create table "mastertable-clinics" (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  address    text,
  pincode    text not null,
  phone      text,
  email      text,
  created_at timestamptz default now()
);

create table "mastertable-pets" (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null references "mastertable-users"(id) on delete cascade,
  name          text not null,
  species       text not null,
  breed         text,
  age           integer,
  weight        numeric(5,2),
  color         text,
  medical_notes text,
  pincode       text not null,
  created_at    timestamptz default now()
);

create table "mastertable-appointments" (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references "mastertable-users"(id) on delete cascade,
  pet_id           uuid not null references "mastertable-pets"(id) on delete cascade,
  clinic_id        uuid not null references "mastertable-clinics"(id) on delete cascade,
  appointment_date timestamptz not null,
  reason           text,
  status           text default 'pending',
  pincode          text not null,
  created_at       timestamptz default now()
);

alter table "mastertable-users"        disable row level security;
alter table "mastertable-pets"         disable row level security;
alter table "mastertable-clinics"      disable row level security;
alter table "mastertable-appointments" disable row level security;

-- ============================================================
-- RPC: register_user
-- Writes to mastertable-users + {pincode}-users
-- {pincode}-users is the read table for all user queries
-- ============================================================
create or replace function register_user(
  p_name    text,
  p_age     integer,
  p_pincode text
)
returns uuid
language plpgsql
security definer
as $$
declare
  master_id uuid;
  users_tbl text := p_pincode || '-users';
begin
  insert into "mastertable-users" (name, age, pincode)
  values (p_name, p_age, p_pincode)
  returning id into master_id;

  execute format('
    create table if not exists %I (
      id         uuid primary key default gen_random_uuid(),
      master_id  uuid not null references "mastertable-users"(id) on delete cascade,
      name       text not null,
      age        integer not null,
      pincode    text not null,
      created_at timestamptz default now()
    )
  ', users_tbl);

  execute format(
    'insert into %I (master_id, name, age, pincode) values (%L::uuid, %L, %L::integer, %L)',
    users_tbl, master_id, p_name, p_age, p_pincode
  );

  return master_id;
end;
$$;

-- ============================================================
-- RPC: register_clinic
-- Writes to mastertable-clinics + {pincode}-clinics
-- ============================================================
create or replace function register_clinic(
  p_name    text,
  p_address text,
  p_pincode text,
  p_phone   text,
  p_email   text
)
returns uuid
language plpgsql
security definer
as $$
declare
  master_id   uuid;
  clinics_tbl text := p_pincode || '-clinics';
begin
  insert into "mastertable-clinics" (name, address, pincode, phone, email)
  values (p_name, p_address, p_pincode, p_phone, p_email)
  returning id into master_id;

  execute format('
    create table if not exists %I (
      id         uuid primary key default gen_random_uuid(),
      master_id  uuid not null references "mastertable-clinics"(id) on delete cascade,
      name       text not null,
      address    text,
      pincode    text not null,
      phone      text,
      email      text,
      created_at timestamptz default now()
    )
  ', clinics_tbl);

  execute format(
    'insert into %I (master_id, name, address, pincode, phone, email) values (%L::uuid, %L, %L, %L, %L, %L)',
    clinics_tbl, master_id, p_name, p_address, p_pincode, p_phone, p_email
  );

  return master_id;
end;
$$;

-- ============================================================
-- RPC: register_pet
-- Writes to mastertable-pets + {pincode}-pets
-- {pincode}-pets.owner_id → {pincode}-users.id  (interlinked)
-- ============================================================
create or replace function register_pet(
  p_owner_master_id uuid,
  p_name            text,
  p_species         text,
  p_breed           text,
  p_age             integer,
  p_weight          numeric,
  p_color           text,
  p_medical_notes   text,
  p_pincode         text
)
returns uuid
language plpgsql
security definer
as $$
declare
  master_id        uuid;
  pincode_owner_id uuid;
  users_tbl        text := p_pincode || '-users';
  pets_tbl         text := p_pincode || '-pets';
begin
  insert into "mastertable-pets" (owner_id, name, species, breed, age, weight, color, medical_notes, pincode)
  values (p_owner_master_id, p_name, p_species, p_breed, p_age, p_weight, p_color, p_medical_notes, p_pincode)
  returning id into master_id;

  -- Resolve owner's row id within the pincode users table
  execute format('select id from %I where master_id = %L', users_tbl, p_owner_master_id)
  into pincode_owner_id;

  execute format('
    create table if not exists %I (
      id            uuid primary key default gen_random_uuid(),
      master_id     uuid not null references "mastertable-pets"(id) on delete cascade,
      owner_id      uuid not null references %I(id) on delete cascade,
      name          text not null,
      species       text not null,
      breed         text,
      age           integer,
      weight        numeric(5,2),
      color         text,
      medical_notes text,
      pincode       text not null,
      created_at    timestamptz default now()
    )
  ', pets_tbl, users_tbl);

  execute format(
    'insert into %I (master_id, owner_id, name, species, breed, age, weight, color, medical_notes, pincode)
     values (%L::uuid, %L::uuid, %L, %L, %L, %L::integer, %L::numeric, %L, %L, %L)',
    pets_tbl, master_id, pincode_owner_id,
    p_name, p_species, p_breed, p_age, p_weight, p_color, p_medical_notes, p_pincode
  );

  return master_id;
end;
$$;

-- ============================================================
-- RPC: create_appointment
-- Writes to mastertable-appointments + {pincode}-appointments
-- {pincode}-appointments FKs:
--   user_id   → {pincode}-users.id
--   pet_id    → {pincode}-pets.id
--   clinic_id → {pincode}-clinics.id
--
-- If clinic belongs to a different pincode, it is copied into
-- the user's pincode clinics table so everything stays within
-- pincode tables (no cross-table reads needed)
-- ============================================================
create or replace function create_appointment(
  p_user_master_id   uuid,
  p_pet_master_id    uuid,
  p_clinic_master_id uuid,
  p_appointment_date timestamptz,
  p_reason           text,
  p_pincode          text
)
returns uuid
language plpgsql
security definer
as $$
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
  insert into "mastertable-appointments" (user_id, pet_id, clinic_id, appointment_date, reason, pincode)
  values (p_user_master_id, p_pet_master_id, p_clinic_master_id, p_appointment_date, p_reason, p_pincode)
  returning id into master_id;

  -- Resolve user row in pincode table
  execute format('select id from %I where master_id = %L', users_tbl, p_user_master_id)
  into pincode_user_id;

  -- Resolve pet row in pincode table
  execute format('select id from %I where master_id = %L', pets_tbl, p_pet_master_id)
  into pincode_pet_id;

  -- Resolve clinic row in pincode table; copy from master if clinic is from a different pincode
  execute format('
    create table if not exists %I (
      id         uuid primary key default gen_random_uuid(),
      master_id  uuid not null references "mastertable-clinics"(id) on delete cascade,
      name       text not null,
      address    text,
      pincode    text not null,
      phone      text,
      email      text,
      created_at timestamptz default now()
    )
  ', clinics_tbl);

  execute format('select id from %I where master_id = %L', clinics_tbl, p_clinic_master_id)
  into pincode_clinic_id;

  if pincode_clinic_id is null then
    select * from "mastertable-clinics" where id = p_clinic_master_id into clinic_rec;
    execute format(
      'insert into %I (master_id, name, address, pincode, phone, email) values (%L::uuid, %L, %L, %L, %L, %L) returning id',
      clinics_tbl, p_clinic_master_id, clinic_rec.name, clinic_rec.address,
      clinic_rec.pincode, clinic_rec.phone, clinic_rec.email
    ) into pincode_clinic_id;
  end if;

  -- Create {pincode}-appointments with FKs fully within pincode tables
  execute format('
    create table if not exists %I (
      id               uuid primary key default gen_random_uuid(),
      master_id        uuid not null references "mastertable-appointments"(id) on delete cascade,
      user_id          uuid not null references %I(id) on delete cascade,
      pet_id           uuid not null references %I(id) on delete cascade,
      clinic_id        uuid not null references %I(id) on delete cascade,
      appointment_date timestamptz not null,
      reason           text,
      status           text default ''pending'',
      pincode          text not null,
      created_at       timestamptz default now()
    )
  ', appointments_tbl, users_tbl, pets_tbl, clinics_tbl);

  execute format(
    'insert into %I (master_id, user_id, pet_id, clinic_id, appointment_date, reason, pincode)
     values (%L::uuid, %L::uuid, %L::uuid, %L::uuid, %L::timestamptz, %L, %L)',
    appointments_tbl, master_id,
    pincode_user_id, pincode_pet_id, pincode_clinic_id,
    p_appointment_date, p_reason, p_pincode
  );

  return master_id;
end;
$$;

-- ============================================================
-- RPC: get_user_profile
-- Reads user + their pets + their appointments (with clinic info)
-- All from pincode tables only — no master table reads
-- ============================================================
create or replace function get_user_profile(
  p_pincode         text,
  p_user_master_id  uuid
)
returns json
language plpgsql
security definer
as $$
declare
  users_tbl        text := p_pincode || '-users';
  pets_tbl         text := p_pincode || '-pets';
  clinics_tbl      text := p_pincode || '-clinics';
  appointments_tbl text := p_pincode || '-appointments';
  result           json;
begin
  execute format('
    select json_build_object(
      ''user'',         row_to_json(u),
      ''pets'',         (select json_agg(p) from %I p where p.owner_id = u.id),
      ''appointments'', (
        select json_agg(
          json_build_object(
            ''appointment'', row_to_json(a),
            ''pet'',         row_to_json(p),
            ''clinic'',      row_to_json(c)
          )
        )
        from %I a
        join %I p on p.id = a.pet_id
        join %I c on c.id = a.clinic_id
        where a.user_id = u.id
      )
    )
    from %I u
    where u.master_id = %L
  ', pets_tbl, appointments_tbl, pets_tbl, clinics_tbl, users_tbl, p_user_master_id)
  into result;

  return result;
end;
$$;

-- ============================================================
-- RPC: get_clinic_profile
-- Reads clinic + all appointments + the users and pets for each
-- All from pincode tables only
-- ============================================================
create or replace function get_clinic_profile(
  p_pincode           text,
  p_clinic_master_id  uuid
)
returns json
language plpgsql
security definer
as $$
declare
  users_tbl        text := p_pincode || '-users';
  pets_tbl         text := p_pincode || '-pets';
  clinics_tbl      text := p_pincode || '-clinics';
  appointments_tbl text := p_pincode || '-appointments';
  result           json;
begin
  execute format('
    select json_build_object(
      ''clinic'',       row_to_json(c),
      ''appointments'', (
        select json_agg(
          json_build_object(
            ''appointment'', row_to_json(a),
            ''user'',        row_to_json(u),
            ''pet'',         row_to_json(p)
          )
        )
        from %I a
        join %I u on u.id = a.user_id
        join %I p on p.id = a.pet_id
        where a.clinic_id = c.id
      )
    )
    from %I c
    where c.master_id = %L
  ', appointments_tbl, users_tbl, pets_tbl, clinics_tbl, p_clinic_master_id)
  into result;

  return result;
end;
$$;

-- ============================================================
-- RPC: get_pincode_summary
-- Returns everything in a pincode: users, pets, clinics, appointments
-- ============================================================
create or replace function get_pincode_summary(p_pincode text)
returns json
language plpgsql
security definer
as $$
declare
  users_tbl        text := p_pincode || '-users';
  pets_tbl         text := p_pincode || '-pets';
  clinics_tbl      text := p_pincode || '-clinics';
  appointments_tbl text := p_pincode || '-appointments';
  result           json;
begin
  execute format('
    select json_build_object(
      ''pincode'',      %L,
      ''users'',        (select json_agg(u) from %I u),
      ''pets'',         (select json_agg(p) from %I p),
      ''clinics'',      (select json_agg(c) from %I c),
      ''appointments'', (select json_agg(a) from %I a)
    )
  ', p_pincode, users_tbl, pets_tbl, clinics_tbl, appointments_tbl)
  into result;

  return result;
end;
$$;

-- ============================================================
-- GRANT ACCESS
-- ============================================================
grant execute on function register_user(text, integer, text)                                                   to anon;
grant execute on function register_clinic(text, text, text, text, text)                                        to anon;
grant execute on function register_pet(uuid, text, text, text, integer, numeric, text, text, text)             to anon;
grant execute on function create_appointment(uuid, uuid, uuid, timestamptz, text, text)                        to anon;
grant execute on function get_user_profile(text, uuid)                                                         to anon;
grant execute on function get_clinic_profile(text, uuid)                                                       to anon;
grant execute on function get_pincode_summary(text)                                                            to anon;
