// Equivalencias de prefijo de OLT (CRC = CRP, etc.) y nombres canónicos de OLT.
const EQUIV_FIJAS = { CRC: "CRP", ESB: "ESM", SPS: "SCP", STS: "STB" };
const OLT_VALIDA = /^[A-Z0-9]{2,8}-OL-[A-Z0-9-]+$/;
export const numDe = (t) => { const m = /(\d+)/.exec(String(t ?? "")); return m ? Number(m[1]) : null; };

export async function mapaEquivalencias(db) {
  const m = { ...EQUIV_FIJAS };
  try { (await db.prepare("SELECT prefijo_alterno a, prefijo_canonico c FROM olt_equivalencias").all()).results.forEach((r) => { m[String(r.a).toUpperCase()] = String(r.c).toUpperCase(); }); } catch (e) { /* tabla aún no creada */ }
  return m;
}
export const canon = (olt, eq) => {
  const s = String(olt || "").trim().toUpperCase();
  if (!OLT_VALIDA.test(s)) return null;
  const [pre, ...resto] = s.split("-");
  return [eq[pre] || pre, ...resto].join("-");
};
export const variantes = (canonOlt, eq) => {
  const [pre, ...resto] = canonOlt.split("-");
  const pres = [pre, ...Object.entries(eq).filter(([, c]) => c === pre).map(([a]) => a)];
  return pres.map((p) => [p, ...resto].join("-"));
};

