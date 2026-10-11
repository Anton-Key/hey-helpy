#!/usr/bin/env bash
# Веб-сборка для сквозных тестов и видео: локальный бэкенд 127.0.0.1:54321,
# речь — заготовленная фраза (VOICE_MOCK), разбор — подменённый «ИИ»
# (VOICE_MOCK_AI + HH_MOCK_AI=1 у бэкенда). Только для локальной проверки,
# в рабочие сборки эти флаги не добавлять.
set -euo pipefail
cd "$(dirname "$0")/../.."
ANON="$(cd tools/e2e && node -e "import('../screens/local_backend.mjs').then(m=>{const n=Math.floor(Date.now()/1000);console.log(m.signJwt({role:'anon',iss:'local',iat:n,exp:n+30*86400}))})")"
DEFINES=(--dart-define=SUPABASE_URL=http://127.0.0.1:54321 "--dart-define=SUPABASE_ANON_KEY=$ANON"
  --dart-define=VOICE_MOCK=true --dart-define=VOICE_MOCK_AI=true)
if [ -f env.json ]; then
  KEY="$(node -e "try{process.stdout.write(require('./env.json').MAP_TILE_KEY||'')}catch{}")"
  [ -n "$KEY" ] && DEFINES+=("--dart-define=MAP_TILE_KEY=$KEY")
fi
flutter build web --release --output build/web_e2e "${DEFINES[@]}" >/dev/null
echo "Сборка: build/web_e2e"
