# Sekiro danger alert development

- The mod's public name is **Sekiro danger alert**. Use it in packages, menus and logs.
- Keep the addon GUID, internal resource path and saved option identifiers stable across upgrades.
- Complete meaningful changes with the relevant offline checks, a descriptive Git commit and a normal push to the configured upstream. The owner has authorized this ongoing workflow.
- Never commit or push `outputs/`, build products, original capture logs, game binaries, local tools or third-party reference checkouts. Do not force-add ignored files.
- The owner publishes GitHub Releases manually. Do not create Releases, release tags or upload release assets automatically.
- Keep read-only engine observations bounded and build-gated. Do not introduce game-memory writes or unverified native calls.
- Preserve third-party attribution and licenses. Do not copy HD2 HUD Plus code or assets into this repository.
- State separately what offline tests prove and what still needs live game validation.
- Run `python scripts/build.py` to create the local package, then `python scripts/test.py --mom-source <ModOptionsMenu checkout>` with `HD2_LUA51_DLL` set to the installed game's Lua DLL.
