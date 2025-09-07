# AJAZZ StreamDock + Lightroom Classic Controller

This workspace contains two plugins that work together:

- StreamDock plugin (Node.js) to map knobs/buttons to Lightroom actions and host a local HTTP queue
- Lightroom Classic plugin (Lua) that polls the queue and applies Develop adjustments via Lightroom SDK

The StreamDock plugin enqueues commands and Lightroom polls them over localhost. Knob rotations send deltas; buttons invoke actions.

## Project layout

- `streamdock-plugin/` — AJAZZ StreamDock plugin (TypeScript)
- `lightroom-plugin/` — Lightroom Classic plugin (`.lrplugin` Lua bundle)

## Quick start (Windows PowerShell)

1) Install Node.js 18+.
2) Install dependencies and start the StreamDock plugin server.

```pwsh
cd "d:\Sources\AJAZZ Lightroom Controller\streamdock-plugin"
npm install
npm start
```

3. Install the StreamDock plugin by pointing StreamDock to this folder (see `plugin.json`).
4. Install the Lightroom plugin by copying `lightroom-plugin/AJAZZLightroom.lrplugin` to your Lightroom plugins folder, then enable it in Lightroom (File > Plug-in Manager).
5. Start Lightroom Classic, open the Develop module, and ensure the plugin is enabled (it polls `http://127.0.0.1:58762/poll`).
6. Start StreamDock, add the plugin to your profile, and map actions to knobs/buttons. Rotating a knob will send incremental deltas to Lightroom.

## Troubleshooting

- If adjustments don’t apply, confirm Lightroom is in Develop module and an image is selected.
- The Lightroom SDK is single-threaded; rapid commands are queued by the HTTP server.
- Firewall prompts: allow local loopback for the StreamDock server when first starting it.

## Notes and limitations

- Global Develop sliders are supported through `LrDevelopController`. Local adjustments (Masks, Brush), Tone Curve point edits, and some panel toggles are not directly controllable via the public SDK.
- HSL is supported via IDs like `HSL.Hue.Red`, `HSL.Sat.Blue`, `HSL.Lum.Green`.
- Temperature/Tint use a different scale; deltas are scaled internally.

## License

MIT
