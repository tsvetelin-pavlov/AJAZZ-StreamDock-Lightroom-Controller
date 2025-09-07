// Logging: forward to console so StreamDock app captures logs in its own log files
const log = {
    info: (...args) => console.log('[info]', ...args),
    warn: (...args) => console.warn('[warn]', ...args),
    error: (...args) => console.error('[error]', ...args),
    debug: (...args) => (console.debug ? console.debug('[debug]', ...args) : console.log('[debug]', ...args)),
};

//##################################################
//################## Global exception handlers #####################
process.on('uncaughtException', (error) => {
    log.error('Uncaught Exception:', error);
});
process.on('unhandledRejection', (reason) => {
    log.error('Unhandled Rejection:', reason);
});
//##################################################
//##################################################


// Plugin class
const ws = require('ws');

// Safely parse a JSON string; return fallback on error
function safeJSONParse(str, fallback) {
    try { return JSON.parse(str); } catch { return fallback; }
}

// Helper to get argv value or undefined
function argv(i) {
    return Array.isArray(process.argv) && process.argv.length > i ? process.argv[i] : undefined;
}

class Plugins {
    static language = (() => {
        const arg = argv(9);
        const obj = typeof arg === 'string' ? safeJSONParse(arg, null) : null;
        return (obj && obj.application && obj.application.language) ? obj.application.language : 'en';
    })();
    static globalSettings = {};
    getGlobalSettingsFlag = true;
    constructor() {
        if (Plugins.instance) {
            return Plugins.instance;
        }
        // Detect if running inside StreamDock (expects specific argv positions)
        const port = argv(3);
        const uuid = argv(5);
        const event = argv(7);

        if (port && uuid && event) {
            // Connected mode: talk to StreamDock runtime over WS
            this.ws = new ws("ws://127.0.0.1:" + port);
            this.ws.on('open', () => this.ws.send(JSON.stringify({ uuid, event })));
            this.ws.on('close', process.exit);
            this.ws.on('message', e => {
                if (this.getGlobalSettingsFlag) {
                    // Only fetch once
                    this.getGlobalSettingsFlag = false;
                    this.getGlobalSettings();
                }
                const data = safeJSONParse(e.toString(), {});
                const action = data.action?.split('.').pop();
                this[action]?.[data.event]?.(data);
                if (data.event === 'didReceiveGlobalSettings') {
                    Plugins.globalSettings = data.payload.settings;
                }
                this[data.event]?.(data);
            });
        } else {
            // Standalone mode: no WS, allow HTTP server to run for local testing
            this.ws = null;
            this.getGlobalSettingsFlag = false;
            log.info('StreamDock WS disabled (standalone run). HTTP bridge can still operate.');
        }

        Plugins.instance = this;
    }

    setGlobalSettings(payload) {
        Plugins.globalSettings = payload;
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "setGlobalSettings",
                context: argv(5), payload
            }));
        }
    }

    getGlobalSettings() {
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "getGlobalSettings",
                context: argv(5),
            }));
        }
    }
    // Set title
    setTitle(context, str, row = 0, num = 6) {
        let newStr = null;
        if (row && str) {
            let nowRow = 1, strArr = str.split('');
            strArr.forEach((item, index) => {
                if (nowRow < row && index >= nowRow * num) { nowRow++; newStr += '\n'; }
                if (nowRow <= row && index < nowRow * num) { newStr += item; }
            });
            if (strArr.length > row * num) { newStr = newStr.substring(0, newStr.length - 1); newStr += '..'; }
        }
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "setTitle",
                context, payload: {
                    target: 0,
                    title: newStr || str + ''
                }
            }));
        }
    }
    // Set background image
    setImage(context, url) {
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "setImage",
                context, payload: {
                    target: 0,
                    image: url
                }
            }));
        }
    }
    // Set state
    setState(context, state) {
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "setState",
                context, payload: { state }
            }));
        }
    }
    // Save persistent data
    setSettings(context, payload) {
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "setSettings",
                context, payload
            }));
        }
    }

    // Show alert on key
    showAlert(context) {
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "showAlert",
                context
            }));
        }
    }

    // Show OK on key
    showOk(context) {
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "showOk",
                context
            }));
        }
    }
    // Send to Property Inspector
    sendToPropertyInspector(payload) {
        if (this.ws) {
            this.ws.send(JSON.stringify({
                action: Actions.currentAction,
                context: Actions.currentContext,
                payload, event: "sendToPropertyInspector"
            }));
        }
    }
    // Open URL in default browser
    openUrl(url) {
        if (this.ws) {
            this.ws.send(JSON.stringify({
                event: "openUrl",
                payload: { url }
            }));
        }
    }
};

// Action class
class Actions {
    constructor(data) {
        this.data = {};
        this.default = {};
        Object.assign(this, data);
    }
    // When Property Inspector appears
    static currentAction = null;
    static currentContext = null;
    static actions = {};
    propertyInspectorDidAppear(data) {
        Actions.currentAction = data.action;
        Actions.currentContext = data.context;
        this._propertyInspectorDidAppear?.(data);
    }
    // Initialize data
    willAppear(data) {
        Plugins.globalContext = data.context;
        Actions.actions[data.context] = data.action
        const { context, payload: { settings } } = data;
        this.data[context] = Object.assign({ ...this.default }, settings);
        this._willAppear?.(data);
    }

    didReceiveSettings(data) {
        this.data[data.context] = data.payload.settings;
        this._didReceiveSettings?.(data);
    }
    // Action disposed
    willDisappear(data) {
        this._willDisappear?.(data);
        delete this.data[data.context];
    }
}

class EventEmitter {
    constructor() {
        this.events = {};
    }

    // Subscribe to event
    subscribe(event, listener) {
        if (!this.events[event]) {
            this.events[event] = [];
        }
        this.events[event].push(listener);
    }

    // Unsubscribe
    unsubscribe(event, listenerToRemove) {
        if (!this.events[event]) return;

        this.events[event] = this.events[event].filter(listener => listener !== listenerToRemove);
    }

    // Publish event
    emit(event, data) {
        if (!this.events[event]) return;
        this.events[event].forEach(listener => listener(data));
    }
}

module.exports = {
    log,
    Plugins,
    Actions,
    EventEmitter
};