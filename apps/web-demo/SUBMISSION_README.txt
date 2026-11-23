WearWise — Interactive Web Demo

This folder is self-contained and can be used for the live presentation.

MACOS
1. Extract the ZIP.
2. If needed, run:
   chmod +x start-demo.command
3. Double-click start-demo.command, or run:
   ./start-demo.command
4. Keep the Terminal window open while demonstrating.

MANUAL LOCAL SERVER
From this folder:
   python3 -m http.server 4173
Then open:
   http://127.0.0.1:4173/

DEMO FLOW
1. Open the wardrobes and show the 28 bundled garment photos.
2. Enter "First dinner with my partner's family" or use a preset.
3. Generate three outfits.
4. Open an outfit and replace one item in the same category.
5. Confirm the outfit and return to the home screen.

IMPORTANT
- No login, backend, API key, CDN, voice recognition, or network is required.
- Recommendations and replacement are deterministic local-demo rules.
- Photos remain local and custom photo uploads are never transmitted.
- The native iOS app and backend are separate parts of the full project.
