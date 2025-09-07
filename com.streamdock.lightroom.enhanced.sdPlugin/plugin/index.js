const { Plugins, Actions, log } = require('./utils/plugin');
const http = require('node:http');

// Initialize plugin bridge to StreamDock runtime
const plugin = new Plugins('lightroom');

// ------------------------
// Lightroom HTTP queue server
// ------------------------
const HOST = '127.0.0.1';
const PORT = 58762; // Must match Lightroom Core.lua poll/ack URLs
const SENS = Number(process.env.LR_KNOB_SENSITIVITY) || 0.03; // ticks to LR delta
const queue = [];

function toLuaTableLiteral(cmd) {
    const parts = ["{ type = '", cmd.type, "', target = '", cmd.target, "'"]; 
    if (typeof cmd.value === 'number') parts.push(', value = ', String(cmd.value));
    parts.push(' }');
    return parts.join('');
}

function enqueue(cmd) {
    const literal = toLuaTableLiteral(cmd);
    queue.push(literal);
    log.info(`[enqueue ${new Date().toISOString()}] ${literal} (len=${queue.length})`);
}

// Per-target default step size (delta value sent to LR per step)
function defaultStepSize(target) {
    const t = String(target || '');
    // Temperature/Tint: Core.lua multiplies by 100, so 0.01 -> 1 unit
    if (t === 'Temperature' || t === 'Temp' || t === 'Tint') return 0.01;
    // Most sliders step at 0.1
    return 0.1;
}

// Try to extract dial ticks from various payload shapes across SDK versions
function extractTicks(payload) {
    if (!payload || typeof payload !== 'object') return 0;
    const cands = [
        payload.ticks,
        payload.delta,
        payload.value,
        payload.step,
        payload.rotation,
        payload.clicks,
        payload?.data?.ticks,
        payload?.data?.delta,
        payload?.data?.value,
    ];
    for (const v of cands) {
        const n = Number(v);
        if (Number.isFinite(n) && n !== 0) return n;
    }
    // Some SDKs provide direction and one-step only
    if (typeof payload.isClockwise === 'boolean') return payload.isClockwise ? 1 : -1;
    if (typeof payload.direction === 'string') {
        if (payload.direction.toLowerCase().includes('clockwise')) return 1;
        if (payload.direction.toLowerCase().includes('counter')) return -1;
    }
    return 0;
}

const server = http.createServer((req, res) => {
    try {
        if (req.method === 'GET' && req.url === '/poll') {
            const item = queue.shift();
            if (item) {
                log.info(`[poll] served item: ${item} (remaining=${queue.length})`);
                res.writeHead(200, { 'Content-Type': 'text/plain' });
                res.end(item);
            } else {
                // No queued items; return 204 without logging to avoid log spam
                res.writeHead(204);
                res.end();
            }
            return;
        }
        if (req.method === 'POST' && req.url === '/ack') {
            // best-effort read body then 200 OK
            req.on('data', () => {});
            req.on('end', () => { log.info('[ack] received'); res.writeHead(200); res.end('ok'); });
            return;
        }
        if (req.method === 'GET' && req.url === '/health') {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end('ok');
            return;
        }
        if (req.method === 'GET' && req.url === '/queueLength') {
            res.writeHead(200, { 'Content-Type': 'text/plain' });
            res.end(String(queue.length));
            return;
        }
        // Diagnostic: allow injecting a command via query string
        // Example: /enqueue?type=invoke&target=ToggleBeforeAfter
        // or: /enqueue?type=delta&target=Exposure2012&value=0.1
        if (req.method === 'GET' && req.url.startsWith('/enqueue')) {
            try {
                const url = new URL(req.url, `http://${HOST}:${PORT}`);
                const type = url.searchParams.get('type') || 'invoke';
                const target = url.searchParams.get('target') || 'ToggleBeforeAfter';
                const valueStr = url.searchParams.get('value'); // direct LR delta
                const stepsStr = url.searchParams.get('steps'); // number of step repeats
                // If steps are specified and this is a delta command, enqueue N small deltas
                if (type === 'delta' && stepsStr != null && stepsStr !== '' && Number.isFinite(Number(stepsStr))) {
                    const steps = Number(stepsStr);
                    const count = Math.trunc(Math.abs(steps));
                    const sign = steps >= 0 ? 1 : -1;
                    const stepSize = defaultStepSize(target) * sign;
                    for (let i = 0; i < count; i++) enqueue({ type: 'delta', target, value: stepSize });
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ ok: true, enqueued: count, stepSize }));
                } else {
                    // Single-shot enqueue, optionally with explicit delta value
                    let value;
                    if (valueStr != null && valueStr !== '' && Number.isFinite(Number(valueStr))) {
                        value = Number(valueStr);
                    }
                    const cmd = { type, target };
                    if (Number.isFinite(value)) cmd.value = value;
                    enqueue(cmd);
                    res.writeHead(200, { 'Content-Type': 'application/json' });
                    res.end(JSON.stringify({ ok: true, queued: cmd }));
                }
            } catch (e) {
                log.error('enqueue endpoint error:', e);
                res.writeHead(400);
                res.end('bad request');
            }
            return;
        }
        res.writeHead(404); res.end('not found');
    } catch (err) {
        log.error('HTTP server error:', err);
        try { res.writeHead(500); res.end('error'); } catch (_) {}
    }
});

server.listen(PORT, HOST, () => {
    log.info(`Lightroom queue server listening at http://${HOST}:${PORT}`);
});

// ------------------------
// StreamDock action wiring
// ------------------------

plugin.didReceiveGlobalSettings = ({ payload: { settings } }) => {
    log.info('didReceiveGlobalSettings', settings);
};

// Helpers to read per-action settings (if any PI is used to configure targets)
function getContextSettings(actionObj, context) {
    try { return actionObj?.data?.[context] || {}; } catch { return {}; }
}

function getTargetFromSettings(actionObj, context) {
    const s = getContextSettings(actionObj, context);
    return s.target || s.paramId; // support both keys
}

function getInvokeActionFromSettings(actionObj, context) {
    const s = getContextSettings(actionObj, context);
    return s.action || s.invokeAction;
}

// Action UUID suffix must match manifest (e.g., com.streamdock.lightroom.enhanced.control -> 'control')
plugin.control = new Actions({
    // You can define defaults that PI may override later
    default: {
        // Example default: 'Exposure2012' if PI not configured
        target: 'Exposure'
    },
    _willAppear({ context }) {
        // Optionally show an "ON" indicator on the key/dial
        try { plugin.setTitle(context, 'LR'); } catch {}
    },
    _willDisappear({ context }) {
        // no-op
    },
    // Property inspector messages can update settings
    sendToPlugin({ payload, context }) {
        // Persist any provided settings
        const current = getContextSettings(plugin.control, context);
        const next = Object.assign({}, current, payload || {});
        plugin.control.data[context] = next;
        plugin.setSettings(context, next);
    },
    // Button press -> invoke action
    keyUp({ context, payload }) {
        try { log.info('control.keyUp payload:', JSON.stringify(payload)); } catch {}
        const actionId = getInvokeActionFromSettings(plugin.control, context) || getTargetFromSettings(plugin.control, context);
        if (!actionId) { log.warn('keyUp with no action/target configured'); return; }
        enqueue({ type: 'invoke', target: actionId });
    },
    // Knob press -> optional alternate action (invoke)
    dialDown({ context /*, payload*/ }) {
        const actionId = getInvokeActionFromSettings(plugin.control, context);
        if (actionId) enqueue({ type: 'invoke', target: actionId });
    },
    // Knob rotate -> delta on target param
    dialRotate({ context, payload }) {
        try { log.info('control.dialRotate payload:', JSON.stringify(payload)); } catch {}
        const target = getTargetFromSettings(plugin.control, context);
        if (!target) { log.warn('dialRotate with no target configured'); return; }
        const ticks = extractTicks(payload);
        log.info(`[dialRotate] ticks=${ticks} SENS=${SENS} direction=${ticks < 0 ? 'CCW' : 'CW'}`);
        if (!Number.isFinite(ticks) || ticks === 0) return;
        const delta = ticks * SENS; // scale ticks to Lightroom delta
        enqueue({ type: 'delta', target, value: delta });
    }
});

// Exposure knob
plugin.exposure = new Actions({
    default: {},
    dialRotate({ context, payload }) {
        try { log.info('exposure.dialRotate payload:', JSON.stringify(payload)); } catch {}
        const ticks = extractTicks(payload);
        if (!Number.isFinite(ticks) || ticks === 0) return;
    enqueue({ type: 'delta', target: 'Exposure2012', value: ticks * SENS });
    }
});

// Contrast knob
plugin.contrast = new Actions({
    default: {},
    dialRotate({ context, payload }) {
        try { log.info('contrast.dialRotate payload:', JSON.stringify(payload)); } catch {}
        const ticks = extractTicks(payload);
        if (!Number.isFinite(ticks) || ticks === 0) return;
    enqueue({ type: 'delta', target: 'Contrast2012', value: ticks * SENS });
    }
});

// Highlights knob
plugin.highlights = new Actions({
    default: {},
    dialRotate({ context, payload }) {
        try { log.info('highlights.dialRotate payload:', JSON.stringify(payload)); } catch {}
        const ticks = extractTicks(payload);
        if (!Number.isFinite(ticks) || ticks === 0) return;
    enqueue({ type: 'delta', target: 'Highlights2012', value: ticks * SENS });
    }
});

// Shadows knob
plugin.shadows = new Actions({
    default: {},
    dialRotate({ context, payload }) {
        try { log.info('shadows.dialRotate payload:', JSON.stringify(payload)); } catch {}
        const ticks = extractTicks(payload);
        if (!Number.isFinite(ticks) || ticks === 0) return;
    enqueue({ type: 'delta', target: 'Shadows2012', value: ticks * SENS });
    }
});

// Buttons
plugin.togglebeforeafter = new Actions({
    default: {},
    keyUp() { enqueue({ type: 'invoke', target: 'ToggleBeforeAfter' }); }
});

plugin.reset = new Actions({
    default: {},
    keyUp() { enqueue({ type: 'invoke', target: 'Reset' }); }
});

plugin.copysettings = new Actions({
    default: {},
    keyUp() { enqueue({ type: 'invoke', target: 'CopySettings' }); }
});

plugin.pastesettings = new Actions({
    default: {},
    keyUp() { enqueue({ type: 'invoke', target: 'PasteSettings' }); }
});