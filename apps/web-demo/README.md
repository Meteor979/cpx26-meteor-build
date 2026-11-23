# WearWise Stage Demo

Static, dependency-free stage demo for the WearWise photo recommendation flow.

The package contains 28 bundled demo garment photos. It runs without a backend,
account, API key, CDN, or network connection after extraction.

## Flow

1. Open the photo wardrobe and use the bundled demonstration garments or add
   local photos.
2. Enter an occasion or choose a preset.
3. Generate three outfit combinations using the actual local image records.
4. Open an outfit, replace a same-slot item, and save it to the recent plan.

All recommendations and replacements in this branch run locally. No wardrobe
photo is uploaded to a server.

## Local server

From the repository root:

```bash
python3 -m http.server 4173 --directory apps/web-demo
```

Open `http://127.0.0.1:4173/`.

The extracted submission package can also be started on macOS by double-clicking
`start-demo.command`, or by running:

```bash
chmod +x start-demo.command
./start-demo.command
```

No network connection is required after the HTML, CSS, JavaScript, and 28
wardrobe photos have been extracted.

## Test

```bash
node apps/web-demo/tests/engine.test.js
```
