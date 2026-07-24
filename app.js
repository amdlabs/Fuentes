/* ============================================================
 * Fuentes · API Flow Tester
 * Editor visual para testear APIs: nodos (rect/rombo/círculo)
 * que representan llamadas HTTP, encadenables entre sí usando
 * plantillas {{Nodo.body.campo}} sobre la respuesta anterior.
 * ============================================================ */

'use strict';

// ------------------------------------------------------------
// Estado
// ------------------------------------------------------------
const STORAGE_KEY = 'fuentes-api-flow-v1';

let state = {
  nodes: [],        // {id, name, shape, x, y, method, url, headers, body}
  connections: [],  // {id, from, to}
};

// Respuestas en memoria (no se persisten): id de nodo -> {status, statusText, headers, body, timeMs}
const responses = {};

let selectedNodeId = null;
let nodeSeq = 1;

// ------------------------------------------------------------
// Referencias DOM
// ------------------------------------------------------------
const canvas = document.getElementById('canvas');
const canvasWrap = document.getElementById('canvas-wrap');
const wires = document.getElementById('wires');
const canvasHint = document.getElementById('canvas-hint');

const propsEmpty = document.getElementById('props-empty');
const propsForm = document.getElementById('props-form');
const pName = document.getElementById('p-name');
const pMethod = document.getElementById('p-method');
const pShape = document.getElementById('p-shape');
const pUrl = document.getElementById('p-url');
const pHeaders = document.getElementById('p-headers');
const pBody = document.getElementById('p-body');
const varsHelp = document.getElementById('vars-help');
const varsList = document.getElementById('vars-list');
const lastResponseBox = document.getElementById('last-response');
const lastResponseBody = document.getElementById('last-response-body');

const consolePanel = document.getElementById('console-panel');
const consoleBody = document.getElementById('console-body');

// ------------------------------------------------------------
// Utilidades
// ------------------------------------------------------------
function uid() {
  return 'n' + Math.random().toString(36).slice(2, 9) + Date.now().toString(36).slice(-4);
}

function getNode(id) {
  return state.nodes.find(n => n.id === id);
}

function saveState() {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch (_) { /* almacenamiento lleno o deshabilitado: se ignora */ }
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    const parsed = JSON.parse(raw);
    if (parsed && Array.isArray(parsed.nodes) && Array.isArray(parsed.connections)) {
      state = parsed;
      nodeSeq = state.nodes.length + 1;
    }
  } catch (_) { /* JSON corrupto: se arranca vacío */ }
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

// ------------------------------------------------------------
// Render de nodos
// ------------------------------------------------------------
function render() {
  // Elimina nodos existentes (el SVG de conexiones se conserva)
  canvas.querySelectorAll('.node').forEach(el => el.remove());
  state.nodes.forEach(n => canvas.appendChild(createNodeEl(n)));
  canvasHint.style.display = state.nodes.length ? 'none' : 'block';
  drawConnections();
}

function createNodeEl(node) {
  const el = document.createElement('div');
  el.className = `node shape-${node.shape}`;
  el.dataset.id = node.id;
  el.style.left = node.x + 'px';
  el.style.top = node.y + 'px';
  if (node.id === selectedNodeId) el.classList.add('selected');

  const resp = responses[node.id];
  const statusCls = resp ? (resp.error || resp.status >= 400 ? 'err' : 'ok') : '';
  const statusTxt = resp ? (resp.error ? 'ERROR' : resp.status) : '';

  el.innerHTML = `
    <div class="node-bg"></div>
    <div class="node-content">
      <span class="node-method ${escapeHtml(node.method)}">${escapeHtml(node.method)}</span>
      <span class="node-name">${escapeHtml(node.name)}</span>
      <span class="node-url">${escapeHtml(node.url || 'sin URL')}</span>
    </div>
    <span class="node-status ${statusCls}">${escapeHtml(String(statusTxt))}</span>
    <span class="port port-in" title="Entrada"></span>
    <span class="port port-out" title="Arrastrar para conectar con otro nodo"></span>
  `;

  el.addEventListener('mousedown', onNodeMouseDown);
  el.querySelector('.port-out').addEventListener('mousedown', e => startWireDrag(e, node.id));
  return el;
}

function nodeEl(id) {
  return canvas.querySelector(`.node[data-id="${id}"]`);
}

// ------------------------------------------------------------
// Conexiones (SVG)
// ------------------------------------------------------------
function portCenter(id, side) {
  const el = nodeEl(id);
  if (!el) return { x: 0, y: 0 };
  const x = el.offsetLeft + (side === 'out' ? el.offsetWidth : 0);
  const y = el.offsetTop + el.offsetHeight / 2;
  return { x, y };
}

function wirePath(a, b) {
  const dx = Math.max(50, Math.abs(b.x - a.x) / 2);
  return `M ${a.x} ${a.y} C ${a.x + dx} ${a.y}, ${b.x - dx} ${b.y}, ${b.x} ${b.y}`;
}

function drawConnections() {
  wires.querySelectorAll('path.wire').forEach(p => p.remove());
  state.connections.forEach(c => {
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('class', 'wire');
    path.setAttribute('d', wirePath(portCenter(c.from, 'out'), portCenter(c.to, 'in')));
    path.addEventListener('click', () => {
      const from = getNode(c.from), to = getNode(c.to);
      if (confirm(`¿Eliminar la conexión ${from ? from.name : '?'} → ${to ? to.name : '?'}?`)) {
        state.connections = state.connections.filter(x => x.id !== c.id);
        saveState();
        drawConnections();
        renderProps();
      }
    });
    wires.appendChild(path);
  });
}

// ¿Existe un camino de `startId` hacia `targetId`? (para evitar ciclos)
function reaches(startId, targetId) {
  const stack = [startId];
  const seen = new Set();
  while (stack.length) {
    const cur = stack.pop();
    if (cur === targetId) return true;
    if (seen.has(cur)) continue;
    seen.add(cur);
    state.connections.filter(c => c.from === cur).forEach(c => stack.push(c.to));
  }
  return false;
}

// ------------------------------------------------------------
// Drag de nodos
// ------------------------------------------------------------
let dragCtx = null; // {node, el, offX, offY, moved}

function onNodeMouseDown(e) {
  if (e.target.classList.contains('port-out')) return; // lo maneja startWireDrag
  if (e.button !== 0) return;
  const el = e.currentTarget;
  const node = getNode(el.dataset.id);
  if (!node) return;

  selectNode(node.id);

  const canvasRect = canvas.getBoundingClientRect();
  dragCtx = {
    node, el, moved: false,
    offX: e.clientX - canvasRect.left - node.x,
    offY: e.clientY - canvasRect.top - node.y,
  };
  e.preventDefault();
}

document.addEventListener('mousemove', e => {
  if (dragCtx) {
    const canvasRect = canvas.getBoundingClientRect();
    const x = Math.max(0, e.clientX - canvasRect.left - dragCtx.offX);
    const y = Math.max(0, e.clientY - canvasRect.top - dragCtx.offY);
    dragCtx.node.x = Math.round(x);
    dragCtx.node.y = Math.round(y);
    dragCtx.el.style.left = dragCtx.node.x + 'px';
    dragCtx.el.style.top = dragCtx.node.y + 'px';
    dragCtx.moved = true;
    drawConnections();
  } else if (wireCtx) {
    moveWireDrag(e);
  }
});

document.addEventListener('mouseup', e => {
  if (dragCtx) {
    if (dragCtx.moved) saveState();
    dragCtx = null;
  }
  if (wireCtx) endWireDrag(e);
});

// ------------------------------------------------------------
// Drag de conexiones (desde puerto de salida)
// ------------------------------------------------------------
let wireCtx = null; // {fromId, tempPath}

function startWireDrag(e, fromId) {
  if (e.button !== 0) return;
  e.stopPropagation();
  e.preventDefault();
  const tempPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  tempPath.setAttribute('class', 'wire-temp');
  wires.appendChild(tempPath);
  wireCtx = { fromId, tempPath };
  moveWireDrag(e);
}

function moveWireDrag(e) {
  const canvasRect = canvas.getBoundingClientRect();
  const cursor = { x: e.clientX - canvasRect.left, y: e.clientY - canvasRect.top };
  wireCtx.tempPath.setAttribute('d', wirePath(portCenter(wireCtx.fromId, 'out'), cursor));

  // resalta el nodo destino potencial
  canvas.querySelectorAll('.port-in.drop-ok').forEach(p => p.classList.remove('drop-ok'));
  const target = targetNodeAt(e);
  if (target && target.dataset.id !== wireCtx.fromId) {
    target.querySelector('.port-in').classList.add('drop-ok');
  }
}

function targetNodeAt(e) {
  const els = document.elementsFromPoint(e.clientX, e.clientY);
  for (const el of els) {
    const node = el.closest ? el.closest('.node') : null;
    if (node) return node;
  }
  return null;
}

function endWireDrag(e) {
  const { fromId, tempPath } = wireCtx;
  wireCtx = null;
  tempPath.remove();
  canvas.querySelectorAll('.port-in.drop-ok').forEach(p => p.classList.remove('drop-ok'));

  const target = targetNodeAt(e);
  if (!target) return;
  const toId = target.dataset.id;
  if (toId === fromId) return;
  if (state.connections.some(c => c.from === fromId && c.to === toId)) return;
  if (reaches(toId, fromId)) {
    logInfo('No se puede conectar: generaría un ciclo en el flujo.');
    return;
  }
  state.connections.push({ id: uid(), from: fromId, to: toId });
  saveState();
  drawConnections();
  renderProps();
}

// ------------------------------------------------------------
// Selección y panel de propiedades
// ------------------------------------------------------------
function selectNode(id) {
  selectedNodeId = id;
  canvas.querySelectorAll('.node').forEach(el =>
    el.classList.toggle('selected', el.dataset.id === id));
  renderProps();
}

canvasWrap.addEventListener('mousedown', e => {
  if (e.target === canvas || e.target === canvasWrap || e.target === wires) {
    selectNode(null);
  }
});

function renderProps() {
  const node = getNode(selectedNodeId);
  if (!node) {
    propsEmpty.hidden = false;
    propsForm.hidden = true;
    return;
  }
  propsEmpty.hidden = true;
  propsForm.hidden = false;

  pName.value = node.name;
  pMethod.value = node.method;
  pShape.value = node.shape;
  pUrl.value = node.url;
  pHeaders.value = node.headers;
  pBody.value = node.body;

  // Variables disponibles según conexiones entrantes
  const incoming = state.connections
    .filter(c => c.to === node.id)
    .map(c => getNode(c.from))
    .filter(Boolean);

  if (incoming.length) {
    varsHelp.hidden = false;
    varsList.innerHTML = '';
    incoming.forEach(src => {
      const suggestions = suggestVars(src);
      suggestions.forEach(v => {
        const li = document.createElement('li');
        li.textContent = v;
        li.title = 'Clic para copiar';
        li.addEventListener('click', () => {
          navigator.clipboard && navigator.clipboard.writeText(v).catch(() => {});
          logInfo(`Copiado: ${v}`);
        });
        varsList.appendChild(li);
      });
    });
  } else {
    varsHelp.hidden = true;
  }

  // Última respuesta
  const resp = responses[node.id];
  if (resp) {
    lastResponseBox.hidden = false;
    lastResponseBody.textContent = formatResponse(resp);
  } else {
    lastResponseBox.hidden = true;
  }
}

// Sugerencias de variables a partir de la última respuesta del nodo origen
function suggestVars(src) {
  const out = [`{{${src.name}.status}}`];
  const resp = responses[src.id];
  if (resp && resp.body && typeof resp.body === 'object') {
    collectPaths(resp.body, `${src.name}.body`, out, 0);
  } else {
    out.push(`{{${src.name}.body.<campo>}}`);
  }
  return out.slice(0, 14);
}

function collectPaths(obj, prefix, out, depth) {
  if (depth > 2 || out.length > 14) return;
  if (Array.isArray(obj)) {
    if (obj.length) collectPaths(obj[0], `${prefix}.0`, out, depth + 1);
    return;
  }
  if (obj && typeof obj === 'object') {
    for (const k of Object.keys(obj)) {
      const val = obj[k];
      if (val && typeof val === 'object') {
        collectPaths(val, `${prefix}.${k}`, out, depth + 1);
      } else {
        out.push(`{{${prefix}.${k}}}`);
      }
      if (out.length > 14) return;
    }
  }
}

// Guardado en vivo de las propiedades
function bindProp(input, key, transform) {
  input.addEventListener('input', () => {
    const node = getNode(selectedNodeId);
    if (!node) return;
    node[key] = transform ? transform(input.value) : input.value;
    saveState();
    updateNodeVisual(node);
  });
}

function updateNodeVisual(node) {
  const el = nodeEl(node.id);
  if (!el) return;
  // La forma cambia la estructura: re-render completo
  if (!el.classList.contains(`shape-${node.shape}`)) {
    render();
    return;
  }
  el.querySelector('.node-name').textContent = node.name;
  el.querySelector('.node-url').textContent = node.url || 'sin URL';
  const m = el.querySelector('.node-method');
  m.textContent = node.method;
  m.className = `node-method ${node.method}`;
  drawConnections();
}

bindProp(pName, 'name');
bindProp(pUrl, 'url');
bindProp(pHeaders, 'headers');
bindProp(pBody, 'body');
pMethod.addEventListener('change', () => {
  const node = getNode(selectedNodeId);
  if (!node) return;
  node.method = pMethod.value;
  saveState();
  updateNodeVisual(node);
});
pShape.addEventListener('change', () => {
  const node = getNode(selectedNodeId);
  if (!node) return;
  node.shape = pShape.value;
  saveState();
  render();
});

document.getElementById('p-delete').addEventListener('click', () => {
  const node = getNode(selectedNodeId);
  if (!node) return;
  if (!confirm(`¿Eliminar el nodo "${node.name}" y sus conexiones?`)) return;
  state.nodes = state.nodes.filter(n => n.id !== node.id);
  state.connections = state.connections.filter(c => c.from !== node.id && c.to !== node.id);
  delete responses[node.id];
  selectedNodeId = null;
  saveState();
  render();
  renderProps();
});

document.getElementById('p-run').addEventListener('click', () => {
  if (selectedNodeId) runNode(selectedNodeId);
});

// ------------------------------------------------------------
// Creación de nodos
// ------------------------------------------------------------
function addNode(shape) {
  const wrapRect = canvasWrap.getBoundingClientRect();
  const node = {
    id: uid(),
    name: `Nodo ${nodeSeq++}`,
    shape,
    x: Math.round(canvasWrap.scrollLeft + wrapRect.width / 2 - 95 + (state.nodes.length % 5) * 40),
    y: Math.round(canvasWrap.scrollTop + wrapRect.height / 2 - 60 + (state.nodes.length % 5) * 40),
    method: 'GET',
    url: '',
    headers: '',
    body: '',
  };
  state.nodes.push(node);
  saveState();
  render();
  selectNode(node.id);
  pName.focus();
  pName.select();
}

document.getElementById('btn-add-rect').addEventListener('click', () => addNode('rect'));
document.getElementById('btn-add-diamond').addEventListener('click', () => addNode('diamond'));
document.getElementById('btn-add-circle').addEventListener('click', () => addNode('circle'));

// ------------------------------------------------------------
// Resolución de plantillas {{Nodo.body.campo}}
// ------------------------------------------------------------
function resolveTemplates(text) {
  if (!text) return text;
  return String(text).replace(/\{\{\s*([^}]+?)\s*\}\}/g, (match, expr) => {
    const value = resolveExpr(expr.trim());
    if (value === undefined) {
      throw new Error(`No se pudo resolver la variable ${match}. ` +
        `Verificá el nombre del nodo, la ruta, y que el nodo origen ya se haya ejecutado.`);
    }
    return typeof value === 'object' ? JSON.stringify(value) : String(value);
  });
}

function resolveExpr(expr) {
  // Formato: NombreNodo.parte(.camino...) — el nombre puede contener puntos no,
  // así que se busca el nombre de nodo más largo que matchee el inicio.
  const src = state.nodes
    .filter(n => expr === n.name || expr.startsWith(n.name + '.'))
    .sort((a, b) => b.name.length - a.name.length)[0];
  if (!src) return undefined;
  const resp = responses[src.id];
  if (!resp) return undefined;

  const rest = expr.slice(src.name.length).replace(/^\./, '');
  if (!rest) return resp.body;

  const parts = rest.split('.');
  const root = parts.shift();

  let cur;
  if (root === 'status') return resp.status;
  else if (root === 'statusText') return resp.statusText;
  else if (root === 'body') cur = resp.body;
  else if (root === 'headers') {
    if (!parts.length) return resp.headers;
    // headers: una sola clave, insensible a mayúsculas
    const key = parts.join('.').toLowerCase();
    return resp.headers[key];
  } else return undefined;

  for (const p of parts) {
    if (cur == null) return undefined;
    cur = cur[p];
  }
  return cur;
}

function parseHeaders(text) {
  const headers = {};
  (text || '').split('\n').forEach(line => {
    const idx = line.indexOf(':');
    if (idx > 0) {
      const key = line.slice(0, idx).trim();
      const val = line.slice(idx + 1).trim();
      if (key) headers[key] = val;
    }
  });
  return headers;
}

// ------------------------------------------------------------
// Ejecución de nodos
// ------------------------------------------------------------
async function runNode(id) {
  const node = getNode(id);
  if (!node) return;
  if (!node.url || !node.url.trim()) {
    logError(node, 'El nodo no tiene URL configurada.');
    return false;
  }

  const el = nodeEl(id);
  if (el) el.classList.add('running');

  let url, headers, bodyText;
  try {
    url = resolveTemplates(node.url.trim());
    headers = parseHeaders(resolveTemplates(node.headers));
    bodyText = node.method === 'GET' ? null : resolveTemplates(node.body);
  } catch (err) {
    if (el) el.classList.remove('running');
    logError(node, err.message);
    setNodeStatus(node.id, 'ERROR', true);
    return false;
  }

  const options = { method: node.method, headers };
  if (bodyText != null && bodyText.trim() !== '') {
    options.body = bodyText;
    const hasCT = Object.keys(headers).some(k => k.toLowerCase() === 'content-type');
    if (!hasCT) {
      try { JSON.parse(bodyText); headers['Content-Type'] = 'application/json'; }
      catch (_) { /* no es JSON: no se fuerza content-type */ }
    }
  }

  const started = performance.now();
  try {
    const res = await fetch(url, options);
    const timeMs = Math.round(performance.now() - started);

    const respHeaders = {};
    res.headers.forEach((v, k) => { respHeaders[k.toLowerCase()] = v; });

    const raw = await res.text();
    let body = raw;
    try { body = JSON.parse(raw); } catch (_) { /* respuesta no-JSON: queda como texto */ }

    responses[node.id] = {
      status: res.status,
      statusText: res.statusText,
      headers: respHeaders,
      body,
      timeMs,
      error: false,
    };

    logResponse(node, { url, options, bodyText }, responses[node.id]);
    setNodeStatus(node.id, res.status, res.status >= 400);
    if (node.id === selectedNodeId) renderProps();
    return res.ok;
  } catch (err) {
    const timeMs = Math.round(performance.now() - started);
    responses[node.id] = { status: 0, statusText: '', headers: {}, body: null, timeMs, error: true };
    logError(node, `${err.message} — Si el endpoint existe, puede ser un bloqueo CORS del navegador (ver README).`);
    setNodeStatus(node.id, 'ERROR', true);
    if (node.id === selectedNodeId) renderProps();
    return false;
  } finally {
    if (el) el.classList.remove('running');
  }
}

function setNodeStatus(id, text, isError) {
  const el = nodeEl(id);
  if (!el) return;
  const badge = el.querySelector('.node-status');
  badge.textContent = text;
  badge.className = 'node-status ' + (isError ? 'err' : 'ok');
}

// Orden topológico (Kahn) para ejecutar el flujo completo
function topologicalOrder() {
  const indeg = {};
  state.nodes.forEach(n => { indeg[n.id] = 0; });
  state.connections.forEach(c => { indeg[c.to] = (indeg[c.to] || 0) + 1; });

  const queue = state.nodes.filter(n => indeg[n.id] === 0).map(n => n.id);
  const order = [];
  while (queue.length) {
    const id = queue.shift();
    order.push(id);
    state.connections.filter(c => c.from === id).forEach(c => {
      if (--indeg[c.to] === 0) queue.push(c.to);
    });
  }
  return order;
}

let flowRunning = false;

async function runFlow() {
  if (flowRunning) return;
  if (!state.nodes.length) {
    logInfo('No hay nodos en el flujo.');
    return;
  }
  flowRunning = true;
  const btn = document.getElementById('btn-run-flow');
  btn.disabled = true;
  btn.textContent = '⏳ Ejecutando…';

  try {
    const order = topologicalOrder();
    logInfo(`Ejecutando flujo: ${order.map(id => getNode(id).name).join(' → ')}`);
    for (const id of order) {
      const ok = await runNode(id);
      if (!ok) {
        const hasDownstream = state.connections.some(c => c.from === id);
        if (hasDownstream) {
          logInfo(`Flujo detenido: "${getNode(id).name}" falló y otros nodos dependen de su respuesta.`);
          break;
        }
      }
    }
    logInfo('Flujo finalizado.');
  } finally {
    flowRunning = false;
    btn.disabled = false;
    btn.textContent = '▶ Ejecutar flujo';
  }
}

document.getElementById('btn-run-flow').addEventListener('click', runFlow);

// ------------------------------------------------------------
// Consola
// ------------------------------------------------------------
function timestamp() {
  return new Date().toLocaleTimeString('es', { hour12: false });
}

function clearWelcome() {
  const w = consoleBody.querySelector('.console-welcome');
  if (w) w.remove();
}

function appendLog(el) {
  clearWelcome();
  consoleBody.appendChild(el);
  consoleBody.scrollTop = consoleBody.scrollHeight;
  consolePanel.classList.remove('collapsed');
}

function logInfo(msg) {
  const el = document.createElement('div');
  el.className = 'log-entry info';
  el.innerHTML = `<div class="log-head"><span class="log-time">${timestamp()}</span>` +
    `<span class="log-msg">${escapeHtml(msg)}</span></div>`;
  appendLog(el);
}

function logError(node, msg) {
  const el = document.createElement('div');
  el.className = 'log-entry err';
  el.innerHTML = `<div class="log-head"><span class="log-time">${timestamp()}</span>` +
    `<span class="log-node">${escapeHtml(node.name)}</span>` +
    `<span class="log-msg error-text">${escapeHtml(msg)}</span></div>`;
  appendLog(el);
}

function formatResponse(resp) {
  if (resp.error) return '(error de red — sin respuesta)';
  const body = typeof resp.body === 'object'
    ? JSON.stringify(resp.body, null, 2)
    : String(resp.body);
  return body;
}

function logResponse(node, req, resp) {
  const ok = !resp.error && resp.status < 400;
  const el = document.createElement('div');
  el.className = `log-entry ${ok ? 'ok' : 'err'}`;

  const head = document.createElement('div');
  head.className = 'log-head';
  head.innerHTML =
    `<span class="log-time">${timestamp()}</span>` +
    `<span class="log-node">${escapeHtml(node.name)}</span>` +
    `<span class="log-req">${escapeHtml(node.method)} ${escapeHtml(req.url)}</span>` +
    `<span class="log-status ${ok ? 'ok' : 'err'}">${resp.status} ${escapeHtml(resp.statusText)}</span>` +
    `<span class="log-ms">${resp.timeMs} ms</span>` +
    `<span class="log-time">(clic para expandir)</span>`;

  const detail = document.createElement('pre');
  detail.className = 'log-detail';
  detail.hidden = true;

  const lines = [];
  lines.push('── Petición ─────────────────────');
  lines.push(`${node.method} ${req.url}`);
  const hdrs = req.options.headers || {};
  Object.keys(hdrs).forEach(k => lines.push(`${k}: ${hdrs[k]}`));
  if (req.bodyText) lines.push('', req.bodyText);
  lines.push('', '── Respuesta ────────────────────');
  lines.push(`${resp.status} ${resp.statusText} · ${resp.timeMs} ms`);
  Object.keys(resp.headers).forEach(k => lines.push(`${k}: ${resp.headers[k]}`));
  lines.push('', formatResponse(resp));
  detail.textContent = lines.join('\n');

  head.addEventListener('click', () => { detail.hidden = !detail.hidden; });

  el.appendChild(head);
  el.appendChild(detail);
  appendLog(el);
}

document.getElementById('btn-console-clear').addEventListener('click', () => {
  consoleBody.innerHTML = '<div class="console-welcome">Las respuestas de los llamados aparecerán acá.</div>';
});

document.getElementById('btn-console-toggle').addEventListener('click', e => {
  consolePanel.classList.toggle('collapsed');
  e.target.textContent = consolePanel.classList.contains('collapsed') ? '▴' : '▾';
});

// ------------------------------------------------------------
// Exportar / Importar / Nuevo / Ejemplo
// ------------------------------------------------------------
document.getElementById('btn-export').addEventListener('click', () => {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'flujo-api.json';
  a.click();
  URL.revokeObjectURL(a.href);
});

document.getElementById('btn-import').addEventListener('click', () => {
  document.getElementById('file-import').click();
});

document.getElementById('file-import').addEventListener('change', e => {
  const file = e.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const parsed = JSON.parse(reader.result);
      if (!parsed || !Array.isArray(parsed.nodes) || !Array.isArray(parsed.connections)) {
        throw new Error('estructura inválida');
      }
      state = parsed;
      selectedNodeId = null;
      nodeSeq = state.nodes.length + 1;
      Object.keys(responses).forEach(k => delete responses[k]);
      saveState();
      render();
      renderProps();
      logInfo(`Flujo importado: ${state.nodes.length} nodos, ${state.connections.length} conexiones.`);
    } catch (err) {
      logInfo(`No se pudo importar el archivo: ${err.message}`);
    }
  };
  reader.readAsText(file);
  e.target.value = '';
});

document.getElementById('btn-clear').addEventListener('click', () => {
  if (state.nodes.length && !confirm('¿Borrar todo el flujo actual?')) return;
  state = { nodes: [], connections: [] };
  selectedNodeId = null;
  nodeSeq = 1;
  Object.keys(responses).forEach(k => delete responses[k]);
  saveState();
  render();
  renderProps();
});

document.getElementById('btn-demo').addEventListener('click', () => {
  if (state.nodes.length && !confirm('Esto reemplaza el flujo actual por el ejemplo. ¿Continuar?')) return;

  const loginId = uid();
  const meId = uid();
  const productsId = uid();

  state = {
    nodes: [
      {
        id: loginId,
        name: 'Login',
        shape: 'rect',
        x: 80, y: 160,
        method: 'POST',
        url: 'https://dummyjson.com/auth/login',
        headers: 'Content-Type: application/json',
        body: '{\n  "username": "emilys",\n  "password": "emilyspass"\n}',
      },
      {
        id: meId,
        name: 'Perfil',
        shape: 'diamond',
        x: 400, y: 120,
        method: 'GET',
        url: 'https://dummyjson.com/auth/me',
        headers: 'Authorization: Bearer {{Login.body.accessToken}}',
        body: '',
      },
      {
        id: productsId,
        name: 'Productos',
        shape: 'circle',
        x: 760, y: 140,
        method: 'GET',
        url: 'https://dummyjson.com/auth/products?limit=3',
        headers: 'Authorization: Bearer {{Login.body.accessToken}}',
        body: '',
      },
    ],
    connections: [
      { id: uid(), from: loginId, to: meId },
      { id: uid(), from: meId, to: productsId },
    ],
  };
  selectedNodeId = null;
  nodeSeq = 4;
  Object.keys(responses).forEach(k => delete responses[k]);
  saveState();
  render();
  renderProps();
  logInfo('Flujo de ejemplo cargado (API pública dummyjson.com): Login → Perfil → Productos. ' +
    'El token del Login se inyecta con {{Login.body.accessToken}}. Probá "▶ Ejecutar flujo".');
});

// ------------------------------------------------------------
// Atajos de teclado
// ------------------------------------------------------------
document.addEventListener('keydown', e => {
  const tag = document.activeElement && document.activeElement.tagName;
  const typing = tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT';
  if (typing) return;

  if ((e.key === 'Delete' || e.key === 'Backspace') && selectedNodeId) {
    document.getElementById('p-delete').click();
  }
});

// ------------------------------------------------------------
// Inicio
// ------------------------------------------------------------
loadState();
render();
renderProps();
