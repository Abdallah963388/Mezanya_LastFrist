#!/bin/bash
set -e
export PUB_CACHE="/home/runner/.pub-cache"
flutter build web --release

# Patch flutter_bootstrap.js:
# 1. Use local CanvasKit instead of CDN (faster, no network dependency)
# 2. Disable service worker (avoids stale cache issues in Replit preview)
python3 -c "
content = open('build/web/flutter_bootstrap.js').read()

# Step 1: Add canvasKitBaseUrl to any existing loader.load call
import re

# Remove serviceWorkerSettings block if present
content = re.sub(
    r'_flutter\.loader\.load\(\{[^}]*serviceWorkerVersion[^}]*\}\s*\}\s*\);',
    '_flutter.loader.load({config:{canvasKitBaseUrl:\"canvaskit/\"}});',
    content
)

# If no serviceWorkerSettings was found, just add canvasKitBaseUrl config
if 'canvasKitBaseUrl' not in content:
    content = content.replace(
        '_flutter.loader.load({',
        '_flutter.loader.load({config:{canvasKitBaseUrl:\"canvaskit/\"},'
    )

open('build/web/flutter_bootstrap.js', 'w').write(content)
print('Patched flutter_bootstrap.js: local CanvasKit + no service worker')
"

echo "Build complete!"
