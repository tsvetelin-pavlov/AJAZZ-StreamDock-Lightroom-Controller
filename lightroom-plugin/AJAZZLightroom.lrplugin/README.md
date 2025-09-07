# AJAZZ Lightroom Plugin (Lua)

## Test steps
1. Save all Lua files as UTF-8 without BOM (VS Code: Save with Encoding > UTF-8).
2. Lightroom Classic > File > Plug-in Manager… > Add… and select this folder.
3. In Library menu:
   - Start StreamDock Server (begins HTTP polling to http://127.0.0.1:58762/poll)
   - Stop StreamDock Server
4. Open Develop module and select a photo.
5. Run the StreamDock plugin server (see ../streamdock-plugin): knob turns enqueue commands.

## Logs
- Windows: %AppData%/Adobe/Lightroom/Logs/ (open latest "Lightroom Classic … Log.log")

## Troubleshooting
- “unexpected symbol near 'ï'”: ensure files saved as UTF‑8 without BOM.
- "attempt to index global 'package'": don’t use package.* in Lightroom; use absolute dofile/loadstring.
- Port conflicts: change port in `modules/Core.lua` and in the StreamDock server.
