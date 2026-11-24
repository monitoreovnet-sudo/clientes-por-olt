// Clientes por OLT — pantalla principal: inicio de sesión, pestañas y usuarios.
// La carga de archivos y los informes están en clientes.js.
const API = "/api";

// ---------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------
// Si el servidor falló por dentro ("Error interno") se muestra también el detalle técnico para poder diagnosticarlo.
function textoErrorApi(data) {
  const base = (data && data.error) || "Error de solicitud";
  return data && data.detalle && /^Error interno/.test(base) ? `${base}: ${data.detalle}` : base;
}
async function apiGet(path) {
  const r = await fetch(API + path);
  const data = await r.json();
  if (!r.ok) throw new Error(textoErrorApi(data));
  return data;
}
async function apiSend(path, method, body) {
  const r = await fetch(API + path, {
    method,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await r.json();
  if (!r.ok) { const err = new Error(textoErrorApi(data)); if (data.reautenticar) err.reautenticar = true; throw err; }
  return data;
}

function showMsg(el, text, ok = true) {
  el.textContent = text;
  el.className = "msg " + (ok ? "ok" : "error");
}

// Separador de miles (punto, como en es-VE): 1234567 -> "1.234.567". Para métricas, nunca para el Nº de ticket.
function formatearMiles(v) {
  if (v === null || v === undefined || v === "") return "";
  const n = Number(v);
  if (!isFinite(n)) return String(v);
  const s = String(Math.trunc(Math.abs(n))).replace(/\B(?=(\d{3})+(?!\d))/g, ".");
  return (n < 0 ? "-" : "") + s;
}


function esc(t) { return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }

function escHtml(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

function exportarCSVGenerico(filasObjetos, nombreArchivo) {
  const ws = XLSX.utils.json_to_sheet(filasObjetos);
  const csv = XLSX.utils.sheet_to_csv(ws);
  const blob = new Blob(["\ufeff" + csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = nombreArchivo;
  a.click();
  URL.revokeObjectURL(url);
}


// Selección múltiple en los filtros de "Clientes por OLT"
const CL_MS = [];   // clientes.js agrega aquí los ids de sus filtros
function llenarSelectSimple(id, opciones, placeholder) {
  const el = document.getElementById(id);
  el.innerHTML = `<option value="">${placeholder}</option>` + opciones.map((o) => `<option value="${o.value}">${o.label}</option>`).join("");
  if (CL_MS.includes(id)) clMsRefrescar(id);
}


const clSel = {};   // id del filtro -> Set de valores marcados (texto)
const clVals = (id) => [...(clSel[id] || [])];
function clMsRefrescar(id) {
  const nativo = document.getElementById(id);
  if (!nativo) return;
  if (!clSel[id]) clSel[id] = new Set();
  let cont = document.getElementById(`${id}_ms`);
  if (!cont) {
    nativo.classList.add("ms-nativo"); nativo.tabIndex = -1;
    cont = document.createElement("div"); cont.className = "ms"; cont.id = `${id}_ms`;
    cont.innerHTML = `<button type="button" class="ms-btn" aria-haspopup="listbox"><span class="ms-txt"></span></button>` +
      `<div class="ms-panel hidden"><div class="ms-lista"></div><div class="ms-pie"><button type="button" class="ms-limpiar">Quitar selección</button></div></div>`;
    nativo.insertAdjacentElement("afterend", cont);
    const panel = cont.querySelector(".ms-panel");
    cont.querySelector(".ms-btn").addEventListener("click", () => {
      const abrir = panel.classList.contains("hidden");
      document.querySelectorAll(".ms-panel").forEach((x) => x.classList.add("hidden"));
      if (abrir) panel.classList.remove("hidden");
    });
    cont.querySelector(".ms-limpiar").addEventListener("click", () => { clSel[id].clear(); clMsRefrescar(id); nativo.dispatchEvent(new Event("change")); });
    cont.querySelector(".ms-lista").addEventListener("change", (e) => {
      const cb = e.target.closest("input[type=checkbox]"); if (!cb) return;
      if (cb.checked) clSel[id].add(cb.value); else clSel[id].delete(cb.value);
      clMsRefrescar(id); nativo.dispatchEvent(new Event("change"));
    });
  }
  const placeholder = nativo.options[0] ? nativo.options[0].textContent : "Todos";
  const ops = [...nativo.options].slice(1).map((o) => [o.value, o.textContent]);
  const validos = new Set(ops.map(([v]) => v));
  [...clSel[id]].forEach((v) => { if (!validos.has(v)) clSel[id].delete(v); });   // lo marcado que ya no existe se quita
  const set = clSel[id], lista = cont.querySelector(".ms-lista"), scroll = lista.scrollTop;
  lista.innerHTML = ops.length
    ? ops.map(([v, l]) => `<label class="ms-op"><input type="checkbox" value="${escHtml(v)}" ${set.has(v) ? "checked" : ""} /><span>${escHtml(l)}</span></label>`).join("")
    : `<div class="ms-vacio">Sin opciones</div>`;
  lista.scrollTop = scroll;
  const etiquetas = ops.filter(([v]) => set.has(v)).map(([, l]) => l);
  cont.querySelector(".ms-txt").textContent = !set.size ? placeholder : etiquetas.length === 1 ? etiquetas[0] : `${set.size} seleccionados`;
  cont.querySelector(".ms-btn").classList.toggle("ms-activo", set.size > 0);
  cont.querySelector(".ms-btn").title = etiquetas.join(", ");
}


document.addEventListener("click", (e) => {
  if (e.target.closest && e.target.closest(".ms")) return;
  document.querySelectorAll(".ms-panel").forEach((p) => p.classList.add("hidden"));
});
document.addEventListener("keydown", (e) => { if (e.key === "Escape") document.querySelectorAll(".ms-panel").forEach((p) => p.classList.add("hidden")); });

function smoEdificioDeDireccion(addr) {
  let t = String(addr ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toUpperCase();
  t = t.replace(/\([^)]*\)/g, " ").replace(/\b(TECNICO|TENICO)\b.*$/, " ").replace(/LIBERTADOR,? DISTRITO CAPITAL/g, " ").replace(/\s+/g, " ").trim();
  const re = /\b(EDIFICIO|EDIF|EDF|RESIDENCIAS|RESIDENCIA|RESID|RES|CONJUNTO RESIDENCIAL|CONJUNTO|CENTRO COMERCIAL|CC|TORRE|QUINTA)\b\.?\s*([A-Z0-9Ñ' ]{2,40}?)(?=\s+(?:PISO|PS|PB|PH|P\d|APTO|APT|APTOS|APARTAMENTO|OFIC|OFICINA|LOC|LOCAL|NIVEL|PLANTA|MEZZANINA|CASA|CALLE|AV|AVENIDA|EL RECREO|BELLO MONTE|BELLOMONTE|URB|URBANIZACION|SABANA|CHACAITO)\b|[,.\-/]|$)/;
  const m = re.exec(t);
  if (!m) return "";
  const tipo = /^(EDIFICIO|EDIF|EDF)$/.test(m[1]) ? "Edif." : /^(RESIDENCIAS|RESIDENCIA|RESID|RES)$/.test(m[1]) ? "Res." : m[1] === "CC" ? "C.C." : m[1][0] + m[1].slice(1).toLowerCase();
  const nombre = m[2].trim();
  if (!nombre || /^\d+$/.test(nombre)) return "";
  return `${tipo} ${nombre.toLowerCase().replace(/(^|\s)\S/g, (c) => c.toUpperCase())}`;
}

// ---------------------------------------------------------------
// Pestañas
// ---------------------------------------------------------------
let currentUser = null;
let LOOKUPS = null;
// Los datos de clientes son personales: solo administrador y supervisor (el servidor lo vuelve a validar en cada llamada).
const TABS_POR_ROL = {
  supervisor: ["informe_olt", "informe_general", "clientes"],
  administrador: ["informe_olt", "informe_general", "clientes", "admin"],
};
let grupoActual = "informes";
function mostrarGrupo(g) {
  grupoActual = g;
  document.querySelectorAll(".grupo-btn").forEach((b) => b.classList.toggle("active", b.dataset.grupo === g));
  document.querySelectorAll(".tab-btn[data-grupo]").forEach((b) => b.classList.toggle("fuera-grupo", b.dataset.grupo !== g));
}
function actualizarGrupos() {
  document.querySelectorAll(".grupo-btn").forEach((gb) => {
    const hay = [...document.querySelectorAll(`.tab-btn[data-grupo="${gb.dataset.grupo}"]`)].some((b) => !b.classList.contains("hidden"));
    gb.classList.toggle("hidden", !hay);
  });
  mostrarGrupo(grupoActual);
}
document.querySelectorAll(".grupo-btn").forEach((gb) => {
  gb.addEventListener("click", () => {
    const g = gb.dataset.grupo;
    const act = document.querySelector(".tab-btn.active");
    if (act && act.dataset.grupo === g) { mostrarGrupo(g); return; }
    const primera = [...document.querySelectorAll(`.tab-btn[data-grupo="${g}"]`)].find((b) => !b.classList.contains("hidden"));
    if (primera) primera.click();
  });
});
document.querySelectorAll(".tab-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    mostrarGrupo(btn.dataset.grupo);
    document.querySelectorAll(".tab-btn").forEach((b) => b.classList.remove("active"));
    document.querySelectorAll(".tab-panel").forEach((p) => p.classList.remove("active"));
    btn.classList.add("active");
    document.getElementById("tab-" + btn.dataset.tab).classList.add("active");
    if (btn.dataset.tab === "informe_general" && window.igAbrir) window.igAbrir();
    if (btn.dataset.tab === "informe_olt" && window.coAbrir) window.coAbrir();
    if (btn.dataset.tab === "clientes" && window.cliCargarBases) { window.cliCargarBases(); if (window.cliCargarAuditorias) window.cliCargarAuditorias(); }
  });
});

async function loadLookups() {
  LOOKUPS = await apiGet("/lookups");
}

function aplicarPermisosRol() {
  document.getElementById("topbar_usuario_nombre").textContent = currentUser.nombre || currentUser.email || "";
  const permitidas = TABS_POR_ROL[currentUser.rol] || [];
  document.querySelectorAll(".tab-btn[data-tab]").forEach((btn) => btn.classList.toggle("hidden", !permitidas.includes(btn.dataset.tab)));
  if (!permitidas.length) {
    document.getElementById("app").innerHTML = '<p class="msg error" style="margin:24px">Tu usuario no tiene acceso a esta aplicación (solo administrador y supervisor). Pide que te cambien el rol.</p>';
    actualizarGrupos();
    return;
  }
  actualizarGrupos();
  const primera = document.querySelector(`.tab-btn[data-tab="${permitidas[0]}"]`);
  if (primera) primera.click();
  if (currentUser.rol === "administrador") cargarUsuarios();
}

// ---------------------------------------------------------------
// Inicio de sesión
// ---------------------------------------------------------------
function mostrarLogin() {
  document.getElementById("login_screen").classList.remove("hidden");
  document.getElementById("app_shell").classList.add("hidden");
}
function mostrarApp() {
  document.getElementById("login_screen").classList.add("hidden");
  document.getElementById("app_shell").classList.remove("hidden");
}


function mostrarCambioPassword() {
  ["login_screen", "app_shell"].forEach((id) => document.getElementById(id).classList.add("hidden"));
  document.getElementById("cambio_screen").classList.remove("hidden");
}
async function iniciarSesionApp() {
  let me = null;
  try { me = await (await fetch(API + "/me")).json(); } catch (e) { me = null; }
  if (me && me.debe_cambiar) { mostrarCambioPassword(); return; }
  if (me && me.sin_usuarios) { ["login_screen", "app_shell", "cambio_screen"].forEach((id) => document.getElementById(id).classList.add("hidden")); document.getElementById("setup_screen").classList.remove("hidden"); return; }
  currentUser = me && me.registrado ? me : null;
  if (!currentUser) { mostrarLogin(); return; }
  mostrarApp();
  await loadLookups();
  aplicarPermisosRol();
}
document.getElementById("login_btn").addEventListener("click", async () => {
  const msg = document.getElementById("login_msg");
  const email = document.getElementById("login_email").value.trim();
  const password = document.getElementById("login_password").value;
  if (!email || !password) { showMsg(msg, "Ingresa correo y contraseña.", false); return; }
  try {
    currentUser = await apiSend("/auth/login", "POST", { email, password });
    document.getElementById("login_password").value = "";
    if (currentUser.debe_cambiar) { mostrarCambioPassword(); return; }
    currentUser.registrado = true;
    mostrarApp();
    await loadLookups();
    aplicarPermisosRol();
  } catch (err) {
    showMsg(msg, err.message, false);
  }
});
document.getElementById("setup_btn").addEventListener("click", async () => {
  const msg = document.getElementById("setup_msg");
  try {
    await apiSend("/auth/primer-admin", "POST", {
      email: document.getElementById("setup_email").value, nombre: document.getElementById("setup_nombre").value,
      password: document.getElementById("setup_password").value, clave: document.getElementById("setup_clave").value });
    showMsg(msg, "Administrador creado. Entrando…", true);
    const r = await apiSend("/auth/login", "POST", { email: document.getElementById("setup_email").value, password: document.getElementById("setup_password").value });
    location.reload();
  } catch (err) { showMsg(msg, err.message, false); }
});
document.getElementById("login_toggle_ojo").addEventListener("click", () => {
  const input = document.getElementById("login_password");
  input.type = input.type === "password" ? "text" : "password";
});
document.getElementById("login_password").addEventListener("keydown", (e) => {
  if (e.key === "Enter") document.getElementById("login_btn").click();
});
// ---- Primer inicio de sesión: crear y confirmar la contraseña ----
document.getElementById("cambio_btn").addEventListener("click", async () => {
  const msg = document.getElementById("cambio_msg");
  const password = document.getElementById("cambio_password").value, confirmar = document.getElementById("cambio_confirmar").value;
  const error = errorPasswordNueva(password);
  if (error) { showMsg(msg, error, false); return; }
  if (password !== confirmar) { showMsg(msg, "Las dos contraseñas no coinciden.", false); return; }
  try {
    await apiSend("/auth/cambiar-password", "POST", { password, confirmar });
    location.reload();
  } catch (err) { showMsg(msg, err.message, false); }
});
function errorPasswordNueva(p) {
  if (String(p).length < 8) return "La contraseña debe tener al menos 8 caracteres.";
  if (!/[0-9]/.test(p)) return "La contraseña debe incluir al menos un número.";
  if (!/[A-ZÁÉÍÓÚÑ]/.test(p)) return "La contraseña debe incluir al menos una letra mayúscula.";
  return null;
}
document.getElementById("cambio_toggle_ojo").addEventListener("click", () => {
  ["cambio_password", "cambio_confirmar"].forEach((id) => { const i = document.getElementById(id); i.type = i.type === "password" ? "text" : "password"; });
});
document.getElementById("cambio_cancelar").addEventListener("click", async () => {
  try { await apiSend("/auth/logout", "POST"); } catch (e) { /* nada */ }
  location.reload();
});

document.getElementById("btn_logout").addEventListener("click", async () => {
  try { await apiSend("/auth/logout", "POST"); } catch (e) { /* no importa si falla */ }
  location.reload();
});


document.getElementById("btn_logout").addEventListener("click", async () => {
  try { await apiSend("/auth/logout", "POST"); } catch (e) { /* no importa si falla */ }
  location.reload();
});

// ---------------------------------------------------------------
// Administración de usuarios (solo administrador)
// ---------------------------------------------------------------
async function cargarUsuarios() {
  const tbody = document.querySelector("#adm_table tbody");
  try {
    const data = await apiGet("/admin/usuarios");
    tbody.innerHTML = "";
    data.usuarios.forEach((u) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${u.email}</td>
        <td><input class="adm-nombre" value="${u.nombre || ""}" /></td>
        <td>
          <select class="adm-rol-sel">
            <option value="supervisor" ${u.rol === "supervisor" ? "selected" : ""}>supervisor</option>
            <option value="administrador" ${u.rol === "administrador" ? "selected" : ""}>administrador</option>
          </select>
        </td>
        <td><input type="checkbox" class="adm-activo" ${u.activo ? "checked" : ""} /></td>
        <td>
          <div class="search-row">
            <input type="password" class="adm-password-actual" value="${u.password_actual || ""}" readonly placeholder="Sin asignar" />
            <button type="button" class="btn-secondary adm-toggle-ojo">👁</button>
          </div>
        </td>
        <td>
          <input type="password" class="adm-password" placeholder="Escribir para cambiar" />
        </td>
        <td>
          <button type="button" class="btn-secondary adm-guardar">Guardar</button>
          <button type="button" class="btn-secondary adm-eliminar">Eliminar</button>
        </td>
      `;
      tr.querySelector(".adm-toggle-ojo").addEventListener("click", () => {
        const input = tr.querySelector(".adm-password-actual");
        input.type = input.type === "password" ? "text" : "password";
      });
      tr.querySelector(".adm-guardar").addEventListener("click", async () => {
        try {
          const password = tr.querySelector(".adm-password").value;
          const body = {
            nombre: tr.querySelector(".adm-nombre").value,
            rol: tr.querySelector(".adm-rol-sel").value,
            activo: tr.querySelector(".adm-activo").checked,
          };
          if (password) body.password = password;
          await apiSend(`/admin/usuarios/${u.id}`, "PATCH", body);
          showMsg(document.getElementById("adm_msg"), `Usuario ${u.email} actualizado.`, true);
          cargarUsuarios();
        } catch (err) {
          showMsg(document.getElementById("adm_msg"), err.message, false);
        }
      });
      tr.querySelector(".adm-eliminar").addEventListener("click", async () => {
        if (!confirm(`¿Eliminar a ${u.email}?`)) return;
        try {
          await apiSend(`/admin/usuarios/${u.id}`, "DELETE");
          cargarUsuarios();
        } catch (err) {
          showMsg(document.getElementById("adm_msg"), err.message, false);
        }
      });
      tbody.appendChild(tr);
    });
  } catch (err) {
    showMsg(document.getElementById("adm_msg"), err.message, false);
  }
}

document.getElementById("adm_btn_crear").addEventListener("click", async () => {
  const msg = document.getElementById("adm_msg");
  try {
    await apiSend("/admin/usuarios", "POST", {
      email: document.getElementById("adm_email").value.trim(),
      nombre: document.getElementById("adm_nombre").value.trim(),
      rol: document.getElementById("adm_rol").value,
      password: document.getElementById("adm_password").value,
    });
    document.getElementById("adm_email").value = "";
    document.getElementById("adm_nombre").value = "";
    document.getElementById("adm_password").value = "";
    showMsg(msg, "Usuario agregado correctamente.", true);
    cargarUsuarios();
  } catch (err) {
    showMsg(msg, err.message, false);
  }
});


iniciarSesionApp();
