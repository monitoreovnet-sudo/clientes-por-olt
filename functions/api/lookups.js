import { json } from "../_lib/helpers.js";

// Catálogos que usan los filtros: oficinas, OLT y qué OLT pertenece a qué oficina.
export async function onRequestGet({ env }) {
  const db = env.DB;
  const [oficinas, olts] = await Promise.all([
    db.prepare("SELECT * FROM oficinas WHERE activo = 1 ORDER BY nombre").all(),
    db.prepare("SELECT id, codigo, oficina_id FROM olts WHERE activo = 1 ORDER BY codigo").all(),
  ]);
  const oltOficina = olts.results.filter((o) => o.oficina_id).map((o) => ({ olt: o.codigo, oficina_id: o.oficina_id }));
  return json({ oficinas: oficinas.results, olts: olts.results.map((o) => ({ id: o.id, codigo: o.codigo })), olt_oficina: oltOficina });
}
