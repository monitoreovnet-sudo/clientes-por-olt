# Clientes por OLT

App aparte (su propia base D1 y su propio proyecto en Cloudflare Pages) con solo tres cosas:

1. **Repositorio de clientes**: carga de archivos de Grafana (base de clientes) y de SmartOLT (ONUs), con la cola nocturna de Grafana.
2. **Clientes por OLT**: lista del cruce Grafana × SmartOLT con filtros y descarga a Excel/CSV.
3. **Reporte General de Clientes**: Oficina → OLT → clientes.

No tiene tickets, informes de tickets, alertas ni clientes afectados. Roles con acceso: administrador y supervisor.

## Instalación (una sola vez)

1. **Repositorio nuevo en GitHub** (por ejemplo `clientes-por-olt`) y sube el contenido de esta carpeta.
2. **Crear la base**: `npx wrangler d1 create clientes_por_olt` → copia el `database_id` que muestra y pégalo en `wrangler.toml`.
3. **Cargar el esquema** (crea las tablas y trae las oficinas, OLT, equivalencias y sucursal de cada OLT):
   `npx wrangler d1 execute clientes_por_olt --remote --file=./schema.sql`
4. **Cloudflare Pages**: Create project → conectar el repositorio → build command vacío → output directory `public`.
5. En el proyecto: Settings → Bindings → D1 → variable `DB` = la base `clientes_por_olt`.
6. Settings → Variables and Secrets: `SESSION_SECRET` (texto largo al azar) y `CRON_TOKEN` (otro texto al azar).
7. Entra a la dirección de la app: como la base está vacía, pide crear el **primer administrador** (la "clave de instalación" es el valor de `SESSION_SECRET`).
8. Cola nocturna de Grafana: en el repositorio de GitHub → Settings → Secrets → `APP_URL` (dirección de la app, sin barra final) y `CRON_TOKEN` (el mismo valor). El flujo `.github/workflows/grafana-noche.yml` la procesa a las 12:00 am de Caracas.

## Importante

- Esta base **empieza vacía**: hay que volver a subir los archivos de Grafana (por sucursal) y los de SmartOLT.
- Los usuarios no se copian de la otra app: crea los tuyos en Administración → Usuarios.
- Las auditorías de SmartOLT ya no se asocian a tickets (no hay tickets en esta app).
