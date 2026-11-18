import { json, badRequest } from "../../_lib/helpers.js";
import { cifrarPassword, validarPasswordNueva } from "../../_lib/auth.js";

// POST /api/auth/primer-admin   Body: { email, nombre, password, clave }
// Solo funciona mientras la tabla de usuarios esté VACÍA (instalación nueva) y exige la "clave de instalación" = el secreto SESSION_SECRET
// que se configuró en Cloudflare. Crea el primer administrador; después ya no sirve para nada.
export async function onRequestPost({ request, env }) {
  const n = (await env.DB.prepare("SELECT COUNT(*) AS n FROM usuarios").first()).n;
  if (n > 0) return json({ error: "La app ya tiene usuarios." }, 403);
  const b = await request.json();
  if (!env.SESSION_SECRET || b.clave !== env.SESSION_SECRET) return json({ error: "La clave de instalación no es correcta." }, 403);
  const email = String(b.email || "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return badRequest("Escribe un correo válido.");
  const err = validarPasswordNueva(b.password);
  if (err) return badRequest(err);
  await env.DB.prepare("INSERT INTO usuarios (email, nombre, rol, activo, password_cifrada, debe_cambiar_password) VALUES (?, ?, 'administrador', 1, ?, 0)")
    .bind(email, String(b.nombre || "").trim() || email, await cifrarPassword(b.password, env)).run();
  return json({ ok: true }, 201);
}
