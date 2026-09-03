#!/bin/sh
set -eu

: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD is required}"
: "${DB_NAME:=moment_blog}"
: "${DB_USER:=kanle}"
: "${DB_PASSWORD:?DB_PASSWORD is required}"
: "${BACKEND_PORT:=4000}"
: "${FRONTEND_PORT:=3000}"

MYSQL_DATA_DIR=/app/data/mysql
MYSQL_SOCKET=/app/data/mysql/mysql.sock
MYSQL_PID_FILE=/app/data/mysql/mysql.pid
MYSQL_PID=
BACKEND_PID=
FRONTEND_PID=

validate_identifier() {
  case "$1" in
    ""|*[!A-Za-z0-9_]* )
      echo "Invalid MySQL identifier: $1" >&2
      exit 1
      ;;
  esac
}

escape_sql_string() {
  printf "%s" "$1" | sed -e 's/\\/\\\\/g' -e "s/'/''/g"
}

validate_identifier "$DB_NAME"
validate_identifier "$DB_USER"

ROOT_PASSWORD_SQL=$(escape_sql_string "$MYSQL_ROOT_PASSWORD")
DB_PASSWORD_SQL=$(escape_sql_string "$DB_PASSWORD")

mkdir -p "$MYSQL_DATA_DIR" /app/data/uploads /app/data/plugins
chown -R mysql:mysql "$MYSQL_DATA_DIR"

if [ ! -d "$MYSQL_DATA_DIR/mysql" ]; then
  if find "$MYSQL_DATA_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo "MySQL data directory is not empty but is not initialized: $MYSQL_DATA_DIR" >&2
    exit 1
  fi

  echo "Initializing MySQL data directory..."
  mysqld --initialize-insecure --user=mysql --datadir="$MYSQL_DATA_DIR"
  MYSQL_FIRST_INIT=1
else
  MYSQL_FIRST_INIT=0
fi

echo "Starting MySQL..."
mysqld \
  --user=mysql \
  --datadir="$MYSQL_DATA_DIR" \
  --socket="$MYSQL_SOCKET" \
  --pid-file="$MYSQL_PID_FILE" \
  --bind-address=127.0.0.1 \
  --port=3306 \
  --skip-name-resolve \
  > /app/data/mysql/mysql.log 2>&1 &
MYSQL_PID=$!

cleanup() {
  if [ -n "${FRONTEND_PID:-}" ]; then
    kill -TERM "$FRONTEND_PID" 2>/dev/null || true
  fi
  if [ -n "${BACKEND_PID:-}" ]; then
    kill -TERM "$BACKEND_PID" 2>/dev/null || true
  fi
  if [ -n "${MYSQL_PID:-}" ]; then
    kill -TERM "$MYSQL_PID" 2>/dev/null || true
  fi
  wait "${FRONTEND_PID:-}" 2>/dev/null || true
  wait "${BACKEND_PID:-}" 2>/dev/null || true
  wait "${MYSQL_PID:-}" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

until mysqladmin --protocol=socket --socket="$MYSQL_SOCKET" ping --silent 2>/dev/null; do
  if ! kill -0 "$MYSQL_PID" 2>/dev/null; then
    echo "MySQL exited before becoming ready. Check /app/data/mysql/mysql.log." >&2
    exit 1
  fi
  echo "MySQL not ready, retry in 2s..."
  sleep 2
done

echo "MySQL ready. Configuring database and user..."
if [ "$MYSQL_FIRST_INIT" = "1" ]; then
  mysql --protocol=socket --socket="$MYSQL_SOCKET" -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PASSWORD_SQL}';
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD_SQL}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD_SQL}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD_SQL}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD_SQL}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
else
  mysql --protocol=socket --socket="$MYSQL_SOCKET" -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD_SQL}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD_SQL}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
CREATE USER IF NOT EXISTS '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD_SQL}';
ALTER USER '${DB_USER}'@'127.0.0.1' IDENTIFIED BY '${DB_PASSWORD_SQL}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
fi

echo "Running seed..."
node /app/backend/dist/scripts/seed.js

echo "Starting backend..."
PORT="$BACKEND_PORT" node /app/backend/dist/index.js &
BACKEND_PID=$!

until node -e "
require('http').get('http://127.0.0.1:${BACKEND_PORT}/api/health', r => {
  process.exit(r.statusCode === 200 ? 0 : 1);
}).on('error', () => process.exit(1));
" 2>/dev/null; do
  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo "Backend exited before becoming healthy." >&2
    exit 1
  fi
  sleep 1
done

echo "Starting frontend..."
cd /app/frontend
PORT="$FRONTEND_PORT" HOSTNAME=0.0.0.0 node server.js &
FRONTEND_PID=$!

while kill -0 "$MYSQL_PID" 2>/dev/null \
  && kill -0 "$BACKEND_PID" 2>/dev/null \
  && kill -0 "$FRONTEND_PID" 2>/dev/null; do
  sleep 2
done

echo "A kanle process exited. Stopping container."
exit 1
