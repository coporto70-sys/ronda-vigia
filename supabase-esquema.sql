-- ============================================================
-- Ronda Vigía — esquema y reglas de acceso para Supabase
-- Proyecto: uipdyrcrkiuvmqjfuvzz
--
-- Cómo ejecutarlo:
--   Supabase → SQL Editor → New query → pega todo esto → Run
--   Se puede volver a ejecutar sin romper nada.
-- ============================================================

-- ------------------------------------------------------------
-- 1. TABLAS
-- ------------------------------------------------------------

-- Un perfil por cada cuenta. Se crea solo al registrarse, con rol
-- 'pendiente': hasta que el administrador le asigne rol e instalación,
-- la cuenta no puede ver absolutamente nada.
create table if not exists public.perfiles (
  id         uuid primary key references auth.users on delete cascade,
  nombre     text not null default '',
  usuario    text unique,
  rol        text not null default 'pendiente'
             check (rol in ('pendiente', 'guardia', 'cliente', 'admin')),
  turno      text not null default 'Noche',
  activo     boolean not null default true,
  creado     timestamptz not null default now()
);

create table if not exists public.instalaciones (
  id         uuid primary key default gen_random_uuid(),
  nombre     text not null,
  cliente    text not null default '',
  direccion  text not null default '',
  activa     boolean not null default true,
  creado     timestamptz not null default now()
);

-- Qué instalaciones puede ver cada perfil. El administrador las ve todas
-- sin necesitar filas aquí.
create table if not exists public.accesos (
  perfil_id      uuid not null references public.perfiles(id) on delete cascade,
  instalacion_id uuid not null references public.instalaciones(id) on delete cascade,
  primary key (perfil_id, instalacion_id)
);

create table if not exists public.puntos (
  id             uuid primary key default gen_random_uuid(),
  instalacion_id uuid not null references public.instalaciones(id) on delete cascade,
  codigo         text not null,
  nombre         text not null,
  zona           text not null default 'General',
  activo         boolean not null default true,
  creado         timestamptz not null default now(),
  unique (instalacion_id, codigo)
);

-- Los tramos van en jsonb: [{"puntoId": "...", "minuto": 8}, ...]
create table if not exists public.rutas (
  id              uuid primary key default gen_random_uuid(),
  instalacion_id  uuid not null references public.instalaciones(id) on delete cascade,
  nombre          text not null,
  tolerancia_min  int  not null default 5,
  orden_estricto  boolean not null default false,
  activa          boolean not null default true,
  tramos          jsonb not null default '[]'::jsonb,
  creado          timestamptz not null default now()
);

-- Las marcas van dentro de la ronda, en jsonb. Así el panel del
-- administrador recibe un solo cambio por marca y la ve aparecer en vivo.
create table if not exists public.rondas (
  id              uuid primary key default gen_random_uuid(),
  instalacion_id  uuid not null references public.instalaciones(id) on delete cascade,
  ruta_id         uuid references public.rutas(id) on delete set null,
  perfil_id       uuid references public.perfiles(id) on delete set null,
  ruta_nombre     text not null default '',
  guardia_nombre  text not null default '',
  inicio          timestamptz not null default now(),
  fin             timestamptz,
  estado          text not null default 'en_curso' check (estado in ('en_curso', 'finalizada')),
  total_puntos    int not null default 0,
  observacion     text not null default '',
  marcas          jsonb not null default '[]'::jsonb,
  actualizado     timestamptz not null default now()
);

create index if not exists rondas_inst_inicio on public.rondas (instalacion_id, inicio desc);
create index if not exists puntos_inst on public.puntos (instalacion_id);
create index if not exists rutas_inst  on public.rutas (instalacion_id);
create index if not exists accesos_perfil on public.accesos (perfil_id);

-- ------------------------------------------------------------
-- 2. PERFIL AUTOMÁTICO AL REGISTRARSE
-- ------------------------------------------------------------
create or replace function public.crear_perfil()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre, usuario, rol)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre', ''),
    coalesce(new.raw_user_meta_data ->> 'usuario', split_part(new.email, '@', 1)),
    'pendiente'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil();

-- ------------------------------------------------------------
-- 3. AYUDANTES PARA LAS REGLAS
-- ------------------------------------------------------------
-- security definer para que puedan leer perfiles sin chocar con las
-- propias reglas de perfiles (evita recursión infinita en las políticas).

create or replace function public.es_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and rol = 'admin' and activo
  );
$$;

create or replace function public.mi_rol()
returns text
language sql stable security definer set search_path = public
as $$
  select rol from public.perfiles where id = auth.uid() and activo;
$$;

create or replace function public.tiene_acceso(inst uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select public.es_admin() or exists (
    select 1
    from public.accesos a
    join public.perfiles p on p.id = a.perfil_id
    where a.perfil_id = auth.uid()
      and a.instalacion_id = inst
      and p.activo
  );
$$;

-- ------------------------------------------------------------
-- 4. REGLAS DE ACCESO (RLS)
-- Aquí es donde los roles pasan a ser seguridad de verdad: las
-- comprueba el servidor, no el navegador.
-- ------------------------------------------------------------
alter table public.perfiles      enable row level security;
alter table public.instalaciones enable row level security;
alter table public.accesos       enable row level security;
alter table public.puntos        enable row level security;
alter table public.rutas         enable row level security;
alter table public.rondas        enable row level security;

-- PERFILES: cada quien ve el suyo; el administrador ve y edita todos.
drop policy if exists perfiles_lectura on public.perfiles;
create policy perfiles_lectura on public.perfiles for select
  using (id = auth.uid() or public.es_admin());

drop policy if exists perfiles_propio on public.perfiles;
create policy perfiles_propio on public.perfiles for update
  using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists perfiles_admin on public.perfiles;
create policy perfiles_admin on public.perfiles for all
  using (public.es_admin()) with check (public.es_admin());

-- INSTALACIONES: se ven las asignadas; sólo el administrador las crea o edita.
drop policy if exists inst_lectura on public.instalaciones;
create policy inst_lectura on public.instalaciones for select
  using (public.tiene_acceso(id));

drop policy if exists inst_admin on public.instalaciones;
create policy inst_admin on public.instalaciones for all
  using (public.es_admin()) with check (public.es_admin());

-- ACCESOS: cada quien ve los suyos; sólo el administrador los reparte.
drop policy if exists accesos_lectura on public.accesos;
create policy accesos_lectura on public.accesos for select
  using (perfil_id = auth.uid() or public.es_admin());

drop policy if exists accesos_admin on public.accesos;
create policy accesos_admin on public.accesos for all
  using (public.es_admin()) with check (public.es_admin());

-- PUNTOS y RUTAS: los lee quien tiene la instalación; los escribe el administrador.
drop policy if exists puntos_lectura on public.puntos;
create policy puntos_lectura on public.puntos for select
  using (public.tiene_acceso(instalacion_id));

drop policy if exists puntos_admin on public.puntos;
create policy puntos_admin on public.puntos for all
  using (public.es_admin()) with check (public.es_admin());

drop policy if exists rutas_lectura on public.rutas;
create policy rutas_lectura on public.rutas for select
  using (public.tiene_acceso(instalacion_id));

drop policy if exists rutas_admin on public.rutas;
create policy rutas_admin on public.rutas for all
  using (public.es_admin()) with check (public.es_admin());

-- RONDAS:
--   leer   → quien tenga la instalación (guardia, cliente o administrador)
--   crear  → sólo guardias y administradores, y a su propio nombre
--   editar → el guardia sólo su propia ronda; el administrador cualquiera
--   borrar → sólo el administrador (un guardia no puede tapar su bitácora)
drop policy if exists rondas_lectura on public.rondas;
create policy rondas_lectura on public.rondas for select
  using (public.tiene_acceso(instalacion_id));

drop policy if exists rondas_crear on public.rondas;
create policy rondas_crear on public.rondas for insert
  with check (
    public.tiene_acceso(instalacion_id)
    and public.mi_rol() in ('guardia', 'admin')
    and (perfil_id = auth.uid() or public.es_admin())
  );

drop policy if exists rondas_editar on public.rondas;
create policy rondas_editar on public.rondas for update
  using (public.es_admin() or (perfil_id = auth.uid() and public.mi_rol() = 'guardia'))
  with check (public.es_admin() or (perfil_id = auth.uid() and public.mi_rol() = 'guardia'));

drop policy if exists rondas_borrar on public.rondas;
create policy rondas_borrar on public.rondas for delete
  using (public.es_admin());

-- ------------------------------------------------------------
-- 5. TIEMPO REAL
-- Para que el panel del administrador reciba las marcas al instante.
-- ------------------------------------------------------------
alter table public.rondas replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.rondas;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.puntos;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.rutas;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.instalaciones;
  exception when duplicate_object then null;
  end;
end $$;

-- ------------------------------------------------------------
-- 6. FOTOS
-- Bucket privado: las fotos se sirven con enlaces temporales, no
-- quedan públicas en internet.
-- ------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('fotos', 'fotos', false)
on conflict (id) do nothing;

-- Las fotos se guardan como  fotos/<instalacion_id>/<ronda_id>/<archivo>.jpg
-- así la primera carpeta dice a qué instalación pertenecen.
drop policy if exists fotos_lectura on storage.objects;
create policy fotos_lectura on storage.objects for select
  using (
    bucket_id = 'fotos'
    and public.tiene_acceso(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists fotos_subir on storage.objects;
create policy fotos_subir on storage.objects for insert
  with check (
    bucket_id = 'fotos'
    and public.tiene_acceso(((storage.foldername(name))[1])::uuid)
    and public.mi_rol() in ('guardia', 'admin')
  );

drop policy if exists fotos_borrar on storage.objects;
create policy fotos_borrar on storage.objects for delete
  using (bucket_id = 'fotos' and public.es_admin());

-- ------------------------------------------------------------
-- 7. HAZTE ADMINISTRADOR
-- Ejecuta ESTO SOLO, y sólo tú, DESPUÉS de haberte registrado en la app.
-- Reemplaza el correo por el que usaste.
--
--   update public.perfiles set rol = 'admin', activo = true
--   where id = (select id from auth.users where email = 'TUCORREO');
--
-- Sin esta línea nadie es administrador y nadie puede asignar roles.
-- ------------------------------------------------------------
