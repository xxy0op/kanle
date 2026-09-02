#!/bin/sh
set -eu

: "${DB_HOST:?DB_HOST is required}"
: "${DB_PORT:=3306}"
: "${DB_USER:?DB_USER is required}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${BACKEND_PORT:=4000}"
: "${FRONTEND_PORT:=3000}"

echo "Waiting for MySQL at ${DB_HOST}:${DB_PORT} ..."

until node -e "
const mysql = require('/app/backend/node_modules/mysql2/promise');
mysql.createConnection({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
}).then(c => c.end()).catch(() => process.exit(1));
" 2>/dev/null; do
  echo "MySQL not ready, retry in 2s..."
  sleep 2
done

echo "MySQL ready. Running seed..."
node /app/backend/dist/scripts/seed.js

echo "Starting backend..."
PORT="${BACKEND_PORT}" node /app/backend/dist/index.js &
BACKEND_PID=$!

cleanup() {
  kill -TERM "${FRONTEND_PID:-}" "${BACKEND_PID}" 2>/dev/null || true
  wait "${FRONTEND_PID:-}" 2>/dev/null || true
  wait "${BACKEND_PID}" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

until node -e "
require('http').get('http://127.0.0.1:${BACKEND_PORT}/api/health', r => {
  process.exit(r.statusCode === 200 ? 0 : 1);
}).on('error', () => process.exit(1));
" 2>/dev/null; do
  if ! kill -0 "${BACKEND_PID}" 2>/dev/null; then
    echo "Backend exited before becoming healthy."
    exit 1
  fi
  sleep 1
done

echo "Starting frontend..."
cd /app/frontend
PORT="${FRONTEND_PORT}" HOSTNAME=0.0.0.0 node server.js &
FRONTEND_PID=$!

while kill -0 "${BACKEND_PID}" 2>/dev/null && kill -0 "${FRONTEND_PID}" 2>/dev/null; do
  sleep 2
done

echo "A kanle process exited. Stopping container."
exit 1
