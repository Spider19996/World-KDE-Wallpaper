# Contributing

World is a pure QML Plasma 6 wallpaper, there is nothing to build.

- `./install.sh` installs it for your user (`-y` restarts Plasma), `./uninstall.sh` removes it.
- `tools/make-package.sh` creates `dist/World-<version>.zip`.
- The picture is `contents/ui/WorldScene.qml` (it takes one theme as `p`), the map geometry is in `geo.js`.
- Themes: `params.js` lists every setting, `builtin.js` the built-in themes, `store.js` the inheritance
  (collection defaults, theme overrides). `ThemeFiles.qml` reads and writes the theme folder, which holds the user themes.
- Texts: use `i18nd("plasma_wallpaper_de.robin.world", "text")`. `tools/update-translations.sh` updates `po/`,
  `tools/build-translations.sh` compiles the `.mo` files (needs gettext). Translations are welcome as `po/<lang>.po`.
- The version is the one in `metadata.json`.
