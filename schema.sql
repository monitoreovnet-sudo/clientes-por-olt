-- Clientes por OLT: esquema de la base D1 (se ejecuta UNA vez en la base nueva).

CREATE TABLE IF NOT EXISTS oficinas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  codigo TEXT NOT NULL,              -- ej. BNO
  nombre TEXT NOT NULL UNIQUE,       -- ej. "BNO - BOCONO"
  estado TEXT,                       -- provincia/estado
  localidad TEXT,
  activo INTEGER NOT NULL DEFAULT 1,
  tipo TEXT NOT NULL DEFAULT 'oficina'   -- 'oficina' (real) | 'especial' (ENLACE, TRAMO, No aplica, tipos no técnicos)
);

CREATE TABLE IF NOT EXISTS olts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  oficina_id INTEGER REFERENCES oficinas(id),
  codigo TEXT NOT NULL UNIQUE,       -- ej. BNO-OL-ZT-AC-001
  num_tarjetas INTEGER NOT NULL DEFAULT 17,
  puertos_por_tarjeta INTEGER NOT NULL DEFAULT 16,
  activo INTEGER NOT NULL DEFAULT 1
, sucursal_grafana TEXT);

CREATE TABLE IF NOT EXISTS usuarios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  nombre TEXT,
  rol TEXT NOT NULL DEFAULT 'analista',   -- administrador | supervisor | especialista | analista
  activo INTEGER NOT NULL DEFAULT 1,
  password_cifrada TEXT,
  debe_cambiar_password INTEGER NOT NULL DEFAULT 1   -- migration_033
, password_hash TEXT);

CREATE TABLE IF NOT EXISTS parametros_cruce (
  clave TEXT PRIMARY KEY,
  valor TEXT NOT NULL,
  descripcion TEXT
);

CREATE TABLE IF NOT EXISTS cargas_base (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  sucursal TEXT NOT NULL,
  archivo TEXT,
  fecha_base TEXT,                       -- del nombre del archivo; si no la trae, la hora de subida (Caracas)
  filas_leidas INTEGER NOT NULL DEFAULT 0,
  filas_descartadas INTEGER NOT NULL DEFAULT 0,
  activos INTEGER NOT NULL DEFAULT 0,
  usuario TEXT,
  fecha TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- UTC
  estado TEXT NOT NULL DEFAULT 'cargando', nuevas INTEGER DEFAULT 0, cambiadas INTEGER DEFAULT 0, existentes INTEGER DEFAULT 0, total_acum INTEGER DEFAULT 0, bajas INTEGER DEFAULT 0, en_cola INTEGER DEFAULT 0,         -- cargando | vigente | reemplazada | fallida
  UNIQUE (sucursal, id)
);

CREATE TABLE IF NOT EXISTS auditorias (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  archivo TEXT,
  olt_id_smartolt TEXT,
  olt_nombre TEXT NOT NULL,
  tarjeta INTEGER,                       -- NULL = toda la OLT
  puerto INTEGER,                        -- NULL = toda la tarjeta / OLT
  estado_filtro TEXT,
  fecha_auditoria_utc TEXT,
  fecha_auditoria_local TEXT NOT NULL,   -- hora de Caracas, confirmada por el usuario al subir
  usuario TEXT,
  fecha_subida TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- UTC
  total_onus INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS auditoria_onus (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  auditoria_id INTEGER NOT NULL REFERENCES auditorias(id) ON DELETE CASCADE,
  carga_id INTEGER REFERENCES cargas_base(id),   -- base usada en el cruce
  base_desactualizada INTEGER NOT NULL DEFAULT 0,
  sn TEXT,
  sn_norm TEXT,
  olt_nombre TEXT NOT NULL,
  tarjeta INTEGER,
  puerto INTEGER,
  onu_num TEXT,
  name_smartolt TEXT,
  contact TEXT,
  status TEXT,                           -- Online | Offline | LOS | Power fail
  last_status_change TEXT,               -- normalizado "AAAA-MM-DDTHH:MM:SS"
  zona TEXT,
  direccion_smartolt TEXT,
  clasificacion TEXT,                    -- falla | powerfail | online | caida_previa
  cuenta TEXT,                           -- NULL = sin cruzar
  metodo_cruce TEXT,                     -- serial | contact | cuenta_en_name | cedula_en_name | nombre
  -- Copia de los datos del cliente al momento del cruce (el listado se reproduce aunque la base se reemplace)
  cli_nombre TEXT,
  cli_telefono TEXT,
  cli_cedula TEXT,
  cli_sector TEXT,
  cli_estado_contrato TEXT,
  cli_sucursal TEXT
, cli_tel_casa TEXT, cli_tel_oficina TEXT, cli_ident_externo TEXT);

CREATE TABLE IF NOT EXISTS olt_equivalencias (
  prefijo_alterno TEXT PRIMARY KEY,
  prefijo_canonico TEXT NOT NULL,
  nota TEXT
);

CREATE TABLE IF NOT EXISTS clientes_olt (
  clave TEXT PRIMARY KEY,            -- serial normalizado de la ONU (o C-<cuenta> si la ONU no trae serial)
  sn_norm TEXT,
  cuenta TEXT NOT NULL,
  olt TEXT NOT NULL,
  tarjeta INTEGER,
  puerto INTEGER,
  onu_num TEXT,
  estado_onu TEXT,                   -- último estado visto en SmartOLT
  visto TEXT,                        -- hora de Caracas de la última auditoría/ticket donde apareció
  nombre TEXT,
  telefono_casa TEXT,
  telefono_oficina TEXT,
  correo TEXT,
  sector TEXT,
  direccion TEXT,
  municipio TEXT,
  parroquia TEXT,
  estado_contrato TEXT,
  sucursal TEXT
, cedula TEXT, estado_geo TEXT, ubicacion TEXT);

CREATE TABLE IF NOT EXISTS olt_conteo (
  olt TEXT PRIMARY KEY,
  n INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS uso_d1 (
  dia    TEXT NOT NULL,
  origen TEXT NOT NULL,
  filas  INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (dia, origen)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS olt_sucursal (
  olt TEXT NOT NULL,            -- código de la OLT, tal como viene en la lista
  sucursal TEXT NOT NULL,       -- nombre de la sucursal tal como la escribe el catálogo (Grafana la trae en mayúsculas)
  PRIMARY KEY (olt, sucursal)
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS sucursal_tablas (
  sucursal TEXT PRIMARY KEY,     -- tal como viene en el archivo de Grafana (ej. CARACAS 2)
  tabla    TEXT NOT NULL UNIQUE, -- cb_caracas_2
  listo    INTEGER NOT NULL DEFAULT 0,   -- 1 cuando ya se terminó de cargar la sucursal en esta tabla (desde ahí se deja de usar la tabla vieja para ella)
  creado   TEXT
) WITHOUT ROWID;

CREATE TABLE IF NOT EXISTS cola_cargas (
  carga_id      INTEGER PRIMARY KEY REFERENCES cargas_base(id),
  estado        TEXT NOT NULL DEFAULT 'subiendo',   -- subiendo | pendiente | espera_confirmacion | lista | error | cancelada
  total_chunks  INTEGER NOT NULL DEFAULT 0,
  sig           INTEGER NOT NULL DEFAULT 0,          -- siguiente trozo por aplicar
  cuentas_chunks INTEGER NOT NULL DEFAULT 0,
  completa      INTEGER NOT NULL DEFAULT 0,
  filas         INTEGER NOT NULL DEFAULT 0,          -- filas del archivo para esta sucursal
  nuevas        INTEGER NOT NULL DEFAULT 0,
  cambiadas     INTEGER NOT NULL DEFAULT 0,
  existentes    INTEGER NOT NULL DEFAULT 0,
  bajas         INTEGER,                              -- se llena cuando espera confirmación o termina
  total_base    INTEGER,
  confirmar     INTEGER NOT NULL DEFAULT 0,
  error         TEXT,
  usuario       TEXT,
  creado        TEXT DEFAULT (datetime('now')),
  actualizado   TEXT
);

CREATE TABLE IF NOT EXISTS cola_grafana (
  carga_id INTEGER NOT NULL,
  tipo     TEXT NOT NULL,       -- 'filas' | 'cuentas'
  seq      INTEGER NOT NULL,
  n        INTEGER NOT NULL DEFAULT 0,
  datos    TEXT NOT NULL,       -- JSON comprimido (gzip) en base64
  PRIMARY KEY (carga_id, tipo, seq)
) WITHOUT ROWID;

CREATE INDEX IF NOT EXISTS idx_cargas_sucursal ON cargas_base(sucursal, estado);
CREATE INDEX IF NOT EXISTS idx_aud_olt ON auditorias(olt_nombre, tarjeta, puerto, fecha_auditoria_local);
CREATE INDEX IF NOT EXISTS idx_ao_aud    ON auditoria_onus(auditoria_id);
CREATE INDEX IF NOT EXISTS idx_ao_puerto ON auditoria_onus(olt_nombre, tarjeta, puerto);
CREATE INDEX IF NOT EXISTS idx_ao_cuenta ON auditoria_onus(cuenta);
CREATE INDEX IF NOT EXISTS idx_colt_olt ON clientes_olt (olt, tarjeta, puerto);

-- oficinas: 98 filas
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (1, 'ACC', 'ACC - ACACIAS', 'ZULIA', 'PUERTOS DE ALTAGRACIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (2, 'ANA', 'ANA - ANACO', 'ANZOATEGUI', 'ANACO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (3, 'APD', 'APD - ALTO PRADO', 'MERIDA', 'ALTO PRADO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (4, 'BNO', 'BNO - BOCONO', 'TRUJILLO', 'BOCONO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (5, 'BRS', 'BRS - BARINAS', 'BARINAS', 'BARINAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (6, 'BTA', 'BTA - BARUTA', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (7, 'CAF', 'CAF - CAFETAL', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (8, 'CAT', 'CAT - CATIA', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (9, 'CAU', 'CAU - CAURIMARE', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (10, 'CCG', 'CCG - CAUCAGUA', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (11, 'CCS', 'CCS - CARACAS', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (12, 'CDA', 'CDA - CENTRO DE ATENCION', 'CENTRO DE ATENCION', 'CENTRO DE ATENCION', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (13, 'CDB', 'CDB - CIUDAD BOLIVAR', 'BOLIVAR', 'CIUDAD BOLIVAR', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (14, 'CDC', 'CDC - CONTROL DE CAMBIOS', 'CONTROL DE CAMBIOS', 'CONTROL DE CAMBIOS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (15, 'CIO', 'CIO - CIUDAD ORINOCO', 'BOLIVAR', 'CIUDAD BOLIVAR', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (16, 'CLA', 'CLA - CELINA', 'ZULIA', 'PUERTOS DE ALTAGRACIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (17, 'CLN', 'CLN - COLON', 'TACHIRA', 'SAN JUAN DE COLON', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (18, 'CORP', 'CORP - INTERNO', 'INTERNO', 'INTERNO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (19, 'CPC', 'CPC - CAPACHO', 'TACHIRA', 'SAN CRISTOBAL', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (20, 'CPT', 'CPT - CARIPITO', 'MONAGAS', 'CARIPITO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (21, 'CRA', 'CRA - CARORA', 'LARA', 'CARORA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (22, 'CRB', 'CRB - LA CARABOBO', 'MERIDA', 'MERIDA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (23, 'CRP', 'CRP - CARUPANO', 'SUCRE', 'CARUPANO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (24, 'CSC', 'CSC - CAJA SECA', 'ZULIA', 'CAJA SECA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (25, 'CTO', 'CTO - COLONCITO', 'TACHIRA', 'COLONCITO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (26, 'CTR', 'CTR - CANTAURA', 'ANZOATEGUI', 'ANACO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (27, 'CUM', 'CUM - CUMANA', 'SUCRE', 'SUCRE', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (28, 'CVE', 'CVE - AV ESPAÑA', 'BOLIVAR', 'CIUDAD BOLIVAR', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (29, 'CVJ', 'CVJ - CARVAJAL', 'VALERA', 'TRUJILLO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (30, 'DCC', 'DCC - DOS CAMINOS', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (31, 'ECS', 'ECS - EL CANTON', 'BARINAS', 'EL CANTON', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (32, 'EJI', 'EJI - EJIDO', 'MERIDA', 'EJIDO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (33, 'ESM', 'ESM - EL SOMBRERO', 'GUARICO', 'EL SOMBRERO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (34, 'GBO', 'GBO - EL GUAYABO', 'ZULIA', 'EL GUAYABO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (35, 'GYB', 'GYB - GUAYABONES', 'MERIDA', 'EL VIGIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (36, 'HPT', 'HPT - HOYO DE LA PUERTA', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (37, 'HUM', 'HUM - LA HUMBOLDT', 'MERIDA', 'MERIDA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (38, 'JBT', 'JBT - JOBITOS', 'ZULIA', 'PUERTOS DE ALTAGRACIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (39, 'LFR', 'LFR - LA FRIA', 'TACHIRA', 'LA FRIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (40, 'LMG', 'LMG - LA MILAGROSA', 'MERIDA', 'MERIDA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (41, 'LPS', 'LPS - LA PEDREGOSA', 'MERIDA', 'MERIDA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (42, 'LVR', 'LVR - VILLA DEL ROSARIO', 'ZULIA', 'MACHIQUES', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (43, 'LZT', 'LZT - LA AZULITA', 'MERIDA', 'EL VIGIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (44, 'MASIVO', 'MASIVO - MASIVO', 'MASIVO', 'MASIVO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (45, 'MAT', 'MAT - LA FLORESTA', 'MONAGAS', 'MATURIN', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (46, 'MAZ', 'MAZ - ZONA INDUSTRIAL', 'MONAGAS', 'MATURIN', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (47, 'MBO', 'MBO - MARACAIBO', 'ZULIA', 'MARACAIBO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (48, 'MCC', 'MCC - MECOCAL', 'ZULIA', 'PUERTOS DE ALTAGRACIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (49, 'MCQ', 'MCQ - MACHIQUES', 'ZULIA', 'MACHIQUES', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (50, 'MON', 'MON - MONTALBAN', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (51, 'MRD', 'MRD - MERIDA', 'MERIDA', 'MERIDA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (52, 'OLV', 'OLV - LOS OLIVOS', 'ZULIA', 'MARACAIBO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (53, 'PAL', 'PAL - PUERTOS DE ALTAGRACIA', 'ZULIA', 'PUERTOS DE ALTAGRACIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (54, 'PCO', 'PCO - CORE 8', 'BOLIVAR', 'PUERTO ORDAZ', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (55, 'PDM', 'PDM - PUNTA DE MATA', 'MONAGAS', 'MATURIN', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (56, 'PGD', 'PGD - PALO GORDO', 'TACHIRA', 'SAN CRISTOBAL', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (57, 'PTO', 'PTO - PUERTO ORDAZ', 'BOLIVAR', 'PUERTO ORDAZ', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (58, 'RBO', 'RBO - RUBIO', 'TACHIRA', 'SAN CRISTOBAL', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (59, 'SAT', 'SAT - SAN ANTONIO DEL TACHIRA', 'TACHIRA', 'SAN ANTONIO DEL TACHIRA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (60, 'SBE', 'SBE - SAN BERNARDINO', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (61, 'SCP', 'SCP - SOCOPO', 'BARINAS', 'SOCOPO', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (62, 'SCR', 'SCR - SAN CRISTOBAL', 'TACHIRA', 'SAN CRISTOBAL', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (63, 'SCZ', 'SCZ - SAN CARLOS', 'ZULIA', 'SANTA BARBARA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (64, 'SEA', 'SEA - SANTA ELENA DE ARENALES', 'MERIDA', 'EL VIGIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (65, 'SFX', 'SFX - SAN FELIX', 'BOLIVAR', 'PUERTO ORDAZ', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (66, 'SJM', 'SJM - SAN JUAN DE LOS MORROS', 'GUARICO', 'SAN JUAN DE LOS MORROS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (67, 'SJP', 'SJP - SAN JOSE DE PERIJA', 'ZULIA', 'MACHIQUES', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (68, 'SMI', 'SMI - SANTA MARIA DE IPIRE', 'GUARICO', 'SANTA MARIA DE IPIRE', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (69, 'STB', 'STB - SANTA BARBARA DE BARINAS', 'BARINAS', 'BARINAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (70, 'STF', 'STF - SANTA FE', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (71, 'SVZ', 'SVZ - SANTA BARBARA DEL ZULIA', 'ZULIA', 'SANTA BARBARA DEL ZULIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (72, 'TBY', 'TBY - TABAY', 'MERIDA', 'MERIDA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (73, 'TGO', 'TGO - EL TIGRITO', 'ANZOATEGUI', 'EL TIGRE', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (74, 'TGR', 'TGR - EL TIGRE', 'ANZOATEGUI', 'EL TIGRE', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (75, 'TMB', 'TMB - TEMBLADOR', 'MONAGAS', 'TEMBLADOR', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (76, 'TPR', 'TPR - TIPURO', 'MONAGAS', 'MATURIN', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (77, 'TRB', 'TRB - TARIBA', 'TACHIRA', 'SAN CRISTOBAL', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (78, 'UNA', 'UNA - UREÑA', 'TACHIRA', 'UREÑA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (79, 'VAL', 'VAL - PASEO LAS INDUSTRIAS', 'CARABOBO', 'VALENCIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (80, 'VBF', 'VBF - BELLA FLORIDA', 'CARABOBO', 'VALENCIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (81, 'VBN', 'VBN - BOLIVAR NORTE', 'CARABOBO', 'VALENCIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (82, 'VDP', 'VDP - VALLE DE LA PASCUA', 'GUARICO', 'VALLE DE LA PASCUA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (83, 'VIC', 'VIC - AV VICTORIA', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (84, 'VIG', 'VIG - EL VIGIA', 'MERIDA', 'EL VIGIA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (85, 'VLR', 'VLR - VALERA', 'TRUJILLO', 'VALERA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (86, 'SGU', 'SGU - SAN AGUSTIN', 'DISTRITO CAPITAL', 'CARACAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (87, 'ACA', 'ACA - ACARIGUA', 'PORTUGUESA', 'ACARIGUA', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (88, 'BCS', 'BCS - BARRANCAS', 'BARINAS', 'BARINAS', 1, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (89, 'SOP', 'LÓGICO', 'N/A', 'N/A', 1, 'especial');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (90, 'ENLACE', 'ENLACE', 'ENLACE', 'ENLACE', 1, 'especial');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (91, 'TRAMO', 'TRAMO', 'TRAMO', 'TRAMO', 1, 'especial');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (92, 'TRONCAL', 'TRONCAL', 'TRONCAL', 'TRONCAL', 1, 'especial');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (93, 'CENTRAL', 'CENTRAL TELEFÓNICA', 'N/A', 'N/A', 1, 'especial');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (94, 'HERRAM', 'HERRAMIENTAS VNET', 'N/A', 'N/A', 1, 'especial');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (95, 'MERCAD', 'MERCADEO', 'N/A', 'N/A', 1, 'especial');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (96, 'PAGOS', 'PAGOS', 'N/A', 'N/A', 1, 'especial');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (97, 'SOP', '1. Soporte técnico, pero no aplica', NULL, NULL, 0, 'oficina');
INSERT OR IGNORE INTO oficinas (id, codigo, nombre, estado, localidad, activo, tipo) VALUES (271, 'SOP', 'SOPORTE TÉCNICO PERO NO APLICA', 'N/A', 'N/A', 1, 'especial');

-- olts: 112 filas
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (1, 50, 'MON-OL-ZT-AC-001', 17, 16, 1, 'Caracas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (2, 83, 'VIC-OL-ZT-AC-001', 17, 16, 1, 'Caracas / Caracas 2');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (3, 83, 'VIC-OL-ZT-AC-002', 17, 16, 1, 'Caracas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (4, 83, 'VIC-OL-ZT-AC-003', 17, 16, 1, 'Caracas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (5, 60, 'SBE-OL-ZT-AC-001', 17, 16, 1, 'Caracas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (6, 60, 'SBE-OL-ZT-AC-002', 17, 16, 1, NULL);
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (7, 60, 'SBE-OL-ZT-AC-003', 17, 16, 1, NULL);
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (8, 70, 'STF-OL-ZT-AC-001', 17, 16, 1, 'Caracas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (9, 8, 'CAT-OL-ZT-AC-001', 17, 16, 1, 'Caracas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (10, 8, 'CAT-OL-ZT-AC-002', 17, 16, 1, NULL);
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (11, 2, 'ANA-OL-ZT-AC-001', 17, 16, 1, 'Anaco');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (12, 26, 'CTR-OL-ZT-AC-001', 17, 16, 1, 'Anaco');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (13, 74, 'TGR-OL-ZT-AC-001', 17, 16, 1, 'El Tigre');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (14, 73, 'TGO-OL-ZT-AC-001', 17, 16, 1, 'Anaco / El Tigre');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (15, 15, 'CIO-OL-ZT-AC-001', 17, 16, 1, 'Ciudad Bolivar / Puerto Ordaz');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (16, 5, 'BRS-OL-ZT-AC-001', 17, 16, 1, 'Barinas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (17, 61, 'SPS-OL-ZT-AC-001', 17, 16, 1, 'Socopo');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (18, 69, 'STS-OL-ZT-AC-001', 17, 16, 1, 'Santa Barbara de Barinas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (19, 88, 'BCS-OL-ZT-AC-001', 17, 16, 1, 'Barinas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (20, 31, 'ECS-OL-ZT-AC-001', 17, 16, 1, 'El Canton');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (21, 57, 'PTO-OL-ZT-AC-001', 17, 16, 1, 'Puerto Ordaz');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (22, 54, 'PCO-OL-ZT-AC-001', 17, 16, 1, 'Ciudad Bolivar / Puerto Ordaz');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (23, 13, 'CDB-OL-ZT-AC-001', 17, 16, 1, 'Ciudad Bolivar');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (24, 13, 'CDB-OL-ZT-AC-002', 17, 16, 1, 'Ciudad Bolivar');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (25, 28, 'CVE-OL-ZT-AC-001', 17, 16, 1, 'Ciudad Bolivar');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (26, 65, 'SFX-OL-ZT-AC-001', 17, 16, 1, 'Puerto Ordaz');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (27, 65, 'SFX-OL-ZT-AC-002', 17, 16, 1, 'Puerto Ordaz');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (28, 79, 'VAL-OL-ZT-AC-001', 17, 16, 1, 'Valencia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (29, 79, 'VAL-OL-ZT-AC-002', 17, 16, 1, NULL);
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (30, 81, 'VBN-OL-ZT-AC-001', 17, 16, 1, 'Valencia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (31, 80, 'VBF-OL-ZT-AC-001', 17, 16, 1, 'Valencia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (32, 66, 'SJM-OL-ZT-AC-001', 17, 16, 1, 'San Juan de los Morros');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (33, 68, 'SMI-OL-ZT-AC-001', 17, 16, 1, NULL);
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (34, 82, 'VDP-OL-ZT-AC-001', 17, 16, 1, 'Valle de la Pascua');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (35, 33, 'ESB-OL-ZT-AC-001', 17, 16, 1, 'El Sombrero');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (36, 21, 'CRA-OL-ZT-AC-001', 17, 16, 1, 'Carora');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (37, 51, 'MRD-OL-ZT-AC-001', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (38, 51, 'MRD-OL-ZT-AC-002', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (39, 37, 'HUM-OL-ZT-AC-001', 17, 16, 1, 'Caja Seca / Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (40, 40, 'LMG-OL-ZT-AC-001', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (41, 40, 'LMG-OL-ZT-AC-002', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (42, 22, 'CRB-OL-ZT-AC-001', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (43, 22, 'CRB-OL-ZT-AC-002', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (44, 3, 'APD-OL-ZT-AC-001', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (45, 84, 'VIG-OL-ZT-AC-001', 17, 16, 1, 'El Vigia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (46, 84, 'VIG-OL-ZT-AC-002', 17, 16, 1, 'El Vigia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (47, 84, 'VIG-OL-ZT-AC-003', 17, 16, 1, 'El Vigia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (48, 84, 'VIG-OL-ZT-AC-004', 17, 16, 1, 'El Vigia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (49, 64, 'SEA-OL-ZT-AC-001', 17, 16, 1, 'El Vigia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (50, 43, 'LZT-OL-ZT-AC-001', 17, 16, 1, 'El Vigia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (51, 41, 'LPS-OL-ZT-AC-001', 17, 16, 1, 'El Vigia / Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (52, 35, 'GYB-OL-ZT-AC-001', 17, 16, 1, 'El Vigia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (53, 72, 'TBY-OL-ZT-AC-001', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (54, 72, 'TBY-OL-ZT-AC-002', 17, 16, 1, 'Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (55, 32, 'EJI-OL-ZT-AC-001', 17, 16, 1, 'El Vigia / Merida');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (56, 7, 'CAF-OL-ZT-AC-001', 17, 16, 1, 'Caracas');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (57, 30, 'DCC-OL-ZT-AC-001', 17, 16, 1, 'Caracas / La Fria / Valera');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (58, 10, 'CCG-OL-ZT-AC-001', 17, 16, 1, 'Caucagua');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (59, 6, 'BTA-OL-ZT-AC-001', 17, 16, 1, 'Caracas 2');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (60, 36, 'HPT-OL-ZT-AC-001', 17, 16, 1, 'Caracas 2');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (61, 45, 'MAT-OL-ZT-AC-001', 17, 16, 1, 'Maturin');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (62, 45, 'MAT-OL-ZT-AC-002', 17, 16, 1, 'Maturin');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (63, 75, 'TMB-OL-ZT-AC-001', 17, 16, 1, 'El Temblador');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (64, 20, 'CPT-OL-ZT-AC-001', 17, 16, 1, 'Caripito');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (65, 20, 'CPT-OL-ZT-AC-002', 17, 16, 1, 'Caripito');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (66, 55, 'PDM-OL-ZT-AC-001', 17, 16, 1, 'Maturin');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (67, 55, 'PDM-OL-ZT-AC-002', 17, 16, 1, 'Maturin');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (68, 55, 'PDM-OL-ZT-AC-003', 17, 16, 1, 'Maturin');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (69, 76, 'TPR-OL-ZT-AC-001', 17, 16, 1, 'Maturin');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (70, 46, 'MAZ-OL-ZT-AC-001', 17, 16, 1, 'Maturin');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (71, 46, 'MAZ-OL-ZT-AC-002', 17, 16, 1, 'Maturin');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (72, 27, 'CUM-OL-ZT-AC-001', 17, 16, 1, 'Cumana');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (73, 23, 'CRC-OL-ZT-AC-001', 17, 16, 1, 'Carupano');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (74, 39, 'LFR-OL-ZT-AC-001', 17, 16, 1, 'La Fria');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (75, 39, 'LFR-OL-ZT-AC-002', 17, 16, 1, 'La Fria');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (76, 25, 'CTO-OL-ZT-AC-001', 17, 16, 1, 'Colon / Coloncito');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (77, 25, 'CTO-OL-ZT-AC-002', 17, 16, 1, 'Colon / Coloncito');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (78, 17, 'CLN-OL-ZT-AC-001', 17, 16, 1, 'Colon');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (79, 58, 'RBO-OL-ZT-AC-001', 17, 16, 1, 'San Cristobal / Santa Barbara');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (80, 58, 'RBO-OL-ZT-AC-002', 17, 16, 1, NULL);
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (81, 19, 'CPC-OL-ZT-AC-001', 17, 16, 1, 'San Cristobal');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (82, 78, 'UNA-OL-ZT-AC-001', 17, 16, 1, 'San Antonio');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (83, 59, 'SAT-OL-ZT-AC-001', 17, 16, 1, 'San Antonio / San Cristobal');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (84, 59, 'SAT-OL-ZT-AC-002', 17, 16, 1, 'San Antonio');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (85, 62, 'SCR-OL-ZT-AC-001', 17, 16, 1, 'San Cristobal');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (86, 62, 'SCR-OL-ZT-AC-002', 17, 16, 1, 'San Cristobal');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (87, 56, 'PGD-OL-ZT-AC-001', 17, 16, 1, 'San Cristobal');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (88, 56, 'PGD-OL-ZT-AC-002', 17, 16, 1, 'San Cristobal');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (89, 77, 'TRB-OL-ZT-AC-001', 17, 16, 1, 'San Cristobal');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (90, 85, 'VLR-OL-ZT-AC-001', 17, 16, 1, 'Valera');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (91, 4, 'BNO-OL-ZT-AC-001', 17, 16, 1, 'Bocono');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (92, 29, 'CVJ-OL-ZT-AC-001', 17, 16, 1, 'Valera');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (93, 29, 'CVJ-OL-ZT-AC-002', 17, 16, 1, 'Valera');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (94, 29, 'CVJ-OL-ZT-AC-003', 17, 16, 1, 'Valera');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (95, 24, 'CSC-OL-ZT-AC-001', 17, 16, 1, 'Caja Seca');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (96, 49, 'MCQ-OL-ZT-AC-001', 17, 16, 1, 'Machiques');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (97, 49, 'MCQ-OL-ZT-AC-002', 17, 16, 1, 'Machiques');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (98, 67, 'SJP-OL-ZT-AC-001', 17, 16, 1, 'Machiques / Puertos de Altagracia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (99, 63, 'SCZ-OL-ZT-AC-001', 17, 16, 1, 'Santa Barbara');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (100, 42, 'LVR-OL-ZT-AC-001', 17, 16, 1, 'Machiques / Puertos de Altagracia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (101, 42, 'LVR-OL-ZT-AC-002', 17, 16, 1, 'Machiques');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (102, 34, 'GBO-OL-ZT-AC-001', 17, 16, 1, 'El Guayabo');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (103, 16, 'CLA-OL-ZT-AC-001', 17, 16, 1, 'Puertos de Altagracia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (104, 38, 'JBT-OL-ZT-AC-001', 17, 16, 1, 'Puertos de Altagracia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (105, 53, 'PAL-OL-ZT-AC-001', 17, 16, 1, 'Puertos de Altagracia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (106, 1, 'ACC-OL-ZT-AC-001', 17, 16, 1, 'Puertos de Altagracia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (107, 48, 'MCC-OL-ZT-AC-001', 17, 16, 1, 'Puertos de Altagracia');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (108, 47, 'MBO-OL-ZT-AC-001', 17, 16, 1, 'Maracaibo');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (109, 23, 'CRP-OL-ZT-AC-001', 17, 16, 1, 'Carupano');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (110, 33, 'ESM-OL-ZT-AC-001', 17, 16, 1, NULL);
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (111, 61, 'SCP-OL-ZT-AC-001', 17, 16, 1, 'Socopo');
INSERT OR IGNORE INTO olts (id, oficina_id, codigo, num_tarjetas, puertos_por_tarjeta, activo, sucursal_grafana) VALUES (112, 69, 'STB-OL-ZT-AC-001', 17, 16, 1, 'Santa Barbara de Barinas');

-- olt_equivalencias: 4 filas
INSERT OR IGNORE INTO olt_equivalencias (prefijo_alterno, prefijo_canonico, nota) VALUES ('CRC', 'CRP', 'Carúpano');
INSERT OR IGNORE INTO olt_equivalencias (prefijo_alterno, prefijo_canonico, nota) VALUES ('ESB', 'ESM', 'El Sombrero');
INSERT OR IGNORE INTO olt_equivalencias (prefijo_alterno, prefijo_canonico, nota) VALUES ('SPS', 'SCP', 'Socopó');
INSERT OR IGNORE INTO olt_equivalencias (prefijo_alterno, prefijo_canonico, nota) VALUES ('STS', 'STB', 'Santa Bárbara de Barinas');

-- olt_sucursal: 137 filas
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('ACC-OL-ZT-AC-001', 'Puertos de Altagracia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('ANA-OL-ZT-AC-001', 'Anaco');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('ANA-OL-ZT-AC-002', 'Anaco');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('APD-OL-ZT-AC-001', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('BCS-OL-ZT-AC-001', 'Barinas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('BNO-OL-ZT-AC-001', 'Bocono');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('BRS-OL-ZT-AC-001', 'Barinas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('BTA-OL-ZT-AC-001', 'Caracas 2');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CAF-OL-ZT-AC-001', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CAT-OL-ZT-AC-001', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CBD-OL-ZT-AC-001', 'Ciudad Bolivar');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CCG-OL-ZT-AC-001', 'Caucagua');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CDB-OL-ZT-AC-001', 'Ciudad Bolivar');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CDB-OL-ZT-AC-002', 'Ciudad Bolivar');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CIO-OL-ZT-AC-001', 'Ciudad Bolivar');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CIO-OL-ZT-AC-001', 'Puerto Ordaz');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CLA-OL-ZT-AC-001', 'Puertos de Altagracia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CLN-OL-ZT-AC-001', 'Colon');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CPC-OL-ZT-AC-001', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CPC-OL-ZT-AC-002', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CPT-OL-ZT-AC-001', 'Caripito');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CPT-OL-ZT-AC-002', 'Caripito');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CPT-OL-ZT-AC-003', 'Caripito');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CRA-OL-ZT-AC-001', 'Carora');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CRA-OL-ZT-AC-002', 'Carora');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CRB-OL-ZT-AC-001', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CRB-OL-ZT-AC-002', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CRC-OL-ZT-AC-001', 'Carupano');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CRP-OL-ZT-AC-001', 'Carupano');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CSC-OL-ZT-AC-001', 'Caja Seca');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CSC-OL-ZT-AC-002', 'Caja Seca');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CSC-OL-ZT-AC-003', 'Caja Seca');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CTO-OL-ZT-AC-001', 'Colon');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CTO-OL-ZT-AC-001', 'Coloncito');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CTO-OL-ZT-AC-002', 'Colon');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CTO-OL-ZT-AC-002', 'Coloncito');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CTR-OL-ZT-AC-001', 'Anaco');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CUM-OL-ZT-AC-001', 'Cumana');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CVE-OL-ZT-AC-001', 'Ciudad Bolivar');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CVJ-OL-ZT-AC-001', 'Valera');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CVJ-OL-ZT-AC-002', 'Valera');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('CVJ-OL-ZT-AC-003', 'Valera');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('DCC-OL-ZT-AC-001', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('DCC-OL-ZT-AC-001', 'La Fria');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('DCC-OL-ZT-AC-001', 'Valera');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('DCC-OL-ZT-AC-002', 'Valera');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('ECS-OL-ZT-AC-001', 'El Canton');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('EJI-OL-ZT-AC-001', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('EJI-OL-ZT-AC-001', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('EJI-OL-ZT-AC-003', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('EJI-OL-ZT-AC-004', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('ESB-OL-ZT-AC-001', 'El Sombrero');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('GBO-OL-ZT-AC-001', 'El Guayabo');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('GYB-OL-ZT-AC-001', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('HPT-OL-ZT-AC-001', 'Caracas 2');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('HUM-OL-ZT-AC-001', 'Caja Seca');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('HUM-OL-ZT-AC-001', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('JBT-OL-ZT-AC-001', 'Puertos de Altagracia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LFR-OL-ZT-AC-001', 'La Fria');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LFR-OL-ZT-AC-002', 'La Fria');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LMG-OL-ZT-AC-001', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LMG-OL-ZT-AC-002', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LPS-OL-ZT-AC-001', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LPS-OL-ZT-AC-001', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LVR-OL-ZT-AC-001', 'Machiques');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LVR-OL-ZT-AC-001', 'Puertos de Altagracia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LVR-OL-ZT-AC-002', 'Machiques');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('LZT-OL-ZT-AC-001', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MAT-OL-ZT-AC-001', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MAT-OL-ZT-AC-002', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MAZ-OL-ZT-AC-001', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MAZ-OL-ZT-AC-002', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MBO-OL-ZT-AC-001', 'Maracaibo');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MCC-OL-ZT-AC-001', 'Puertos de Altagracia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MCQ-OL-ZT-AC-001', 'Machiques');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MCQ-OL-ZT-AC-002', 'Machiques');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MON-OL-ZT-AC-001', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MRD-OL-ZT-AC-001', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('MRD-OL-ZT-AC-002', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PAL-OL-ZT-AC-001', 'Puertos de Altagracia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PCO-OL-ZT-AC-001', 'Ciudad Bolivar');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PCO-OL-ZT-AC-001', 'Puerto Ordaz');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PDM-OL-ZT-AC-001', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PDM-OL-ZT-AC-002', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PDM-OL-ZT-AC-003', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PGD-OL-ZT-AC-001', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PGD-OL-ZT-AC-002', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PTO-OL-ZT-AC-001', 'Puerto Ordaz');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('PTO-OL-ZT-AC-002', 'Puerto Ordaz');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('RBO-OL-ZT-AC-001', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('RBO-OL-ZT-AC-001', 'Santa Barbara');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SAT-OL-ZT-AC-001', 'San Antonio');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SAT-OL-ZT-AC-001', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SAT-OL-ZT-AC-002', 'San Antonio');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SBE-OL-ZT-AC-001', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SCP-OL-ZT-AC-001', 'Socopo');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SCR-OL-ZT-AC-001', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SCR-OL-ZT-AC-002', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SCZ-OL-ZT-AC-001', 'Santa Barbara');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SCZ-OL-ZT-AC-002', 'Santa Barbara');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SCZ-OL-ZT-AC-003', 'Santa Barbara');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SCZ-OL-ZT-AC-004', 'Santa Barbara');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SEA-OL-ZT-AC-001', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SFX-OL-ZT-AC-001', 'Puerto Ordaz');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SFX-OL-ZT-AC-002', 'Puerto Ordaz');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SJM-OL-ZT-AC-001', 'San Juan de los Morros');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SJP-OL-ZT-AC-001', 'Machiques');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SJP-OL-ZT-AC-001', 'Puertos de Altagracia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('SPS-OL-ZT-AC-001', 'Socopo');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('STB-OL-ZT-AC-001', 'Santa Barbara de Barinas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('STF-OL-ZT-AC-001', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('STS-OL-ZT-AC-001', 'Santa Barbara de Barinas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TBY-OL-ZT-AC-001', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TBY-OL-ZT-AC-002', 'Merida');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TGO-OL-ZT-AC-001', 'Anaco');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TGO-OL-ZT-AC-001', 'El Tigre');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TGR-OL-ZT-AC-001', 'El Tigre');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TMB-OL-ZT-AC-001', 'El Temblador');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TPR-OL-ZT-AC-001', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TPR-OL-ZT-AC-003', 'Maturin');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TRB-OL-ZT-AC-001', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('TRB-OL-ZT-AC-003', 'San Cristobal');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('UNA-OL-ZT-AC-001', 'San Antonio');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VAL-OL-ZT-AC-001', 'Valencia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VBF-OL-ZT-AC-001', 'Valencia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VBN-OL-ZT-AC-001', 'Valencia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VDP-OL-ZT-AC-001', 'Valle de la Pascua');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIC-OL-ZT-AC-00', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIC-OL-ZT-AC-001', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIC-OL-ZT-AC-001', 'Caracas 2');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIC-OL-ZT-AC-002', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIC-OL-ZT-AC-003', 'Caracas');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIG-OL-ZT-AC-001', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIG-OL-ZT-AC-002', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIG-OL-ZT-AC-003', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VIG-OL-ZT-AC-004', 'El Vigia');
INSERT OR IGNORE INTO olt_sucursal (olt, sucursal) VALUES ('VLR-OL-ZT-AC-001', 'Valera');

-- parametros_cruce: 5 filas
INSERT OR IGNORE INTO parametros_cruce (clave, valor, descripcion) VALUES ('margen_caida_previa_horas', '1', 'Sin Fecha de la falla: referencia = Apertura CMR menos estas horas');
INSERT OR IGNORE INTO parametros_cruce (clave, valor, descripcion) VALUES ('tolerancia_base_horas', '12', 'Diferencia máxima (horas) entre la base Grafana de la sucursal y la auditoría SmartOLT');
INSERT OR IGNORE INTO parametros_cruce (clave, valor, descripcion) VALUES ('umbral_alerta_onus', '1', 'ONUs afectadas en un puerto sin ticket para levantar "Posible falla no reportada"');
INSERT OR IGNORE INTO parametros_cruce (clave, valor, descripcion) VALUES ('ventana_ticket_grafana_dias', '2', 'Diferencia máxima (días) entre la carga de las ONUs de un ticket y la fecha del archivo de Grafana para cruzarlas');
INSERT OR IGNORE INTO parametros_cruce (clave, valor, descripcion) VALUES ('conteos_clientes_listo', '0', 'Interno: 1 cuando ya se llenó el conteo guardado de clientes afectados por registro');

