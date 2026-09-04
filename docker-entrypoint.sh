#!/bin/sh
set -eu

DATA_DIR=/app/data
GENERATED_ENV_FILE="$DATA_DIR/.env.generated"
MYSQL_DATA_DIR="$DATA_DIR/mysql"
MYSQL_SOCKET="$MYSQL_DATA_DIR/mysql.sock"
MYSQL_PID_FILE="$MYSQL_DATA_DIR/mysql.pid"
MYSQL_PID=
BACKEND_PID=
FRONTEND_PID=

mkdir -p "$DATA_DIR"
umask 077

GENERATED_ENV_EXISTS=0
MYSQL_ROOT_PASSWORD_INPUT=${MYSQL_ROOT_PASSWORD-}
if [ -f "$GENERATED_ENV_FILE" ]; then
  # The file is generated below with hex-only values and mode 600.
  . "$GENERATED_ENV_FILE"
  GENERATED_ENV_EXISTS=1
fi

: "${DB_NAME:=moment_blog}"
: "${DB_USER:=kanle}"
: "${NODE_ENV:=production}"
: "${BACKEND_PORT:=4000}"
: "${FRONTEND_PORT:=3000}"
: "${DB_HOST:=127.0.0.1}"
: "${DB_PORT:=3306}"
: "${JWT_EXPIRES_IN:=7d}"
: "${ADMIN_EMAIL:=admin@kanle.net}"
: "${ADMIN_USERNAME:=admin}"
: "${CLIENT_URL:=http://localhost:3000}"
: "${REVALIDATE_URL:=http://127.0.0.1:3000}"

validate_identifier() {
  case "$1" in
    ""|*[!A-Za-z0-9_]* )
      echo "Invalid MySQL identifier: $1" >&2
      exit 1
      ;;
  esac
}

validate_identifier "$DB_NAME"
validate_identifier "$DB_USER"

random_hex() {
  node -e "process.stdout.write(require('crypto').randomBytes(24).toString('hex'))"
}

# All generated values are hex-only, so the persisted file can be safely sourced.
if [ "$GENERATED_ENV_EXISTS" = "0" ]; then
  MYSQL_ROOT_PASSWORD=$(random_hex)
  DB_PASSWORD=$(random_hex)
  JWT_SECRET=$(random_hex)
  REVALIDATE_SECRET=$(random_hex)
  ADMIN_PASSWORD=$(random_hex)
  ADMIN_PASSWORD_GENERATED=1
else
  : "${MYSQL_ROOT_PASSWORD:=$(random_hex)}"
  : "${DB_PASSWORD:=$(random_hex)}"
  : "${JWT_SECRET:=$(random_hex)}"
  : "${REVALIDATE_SECRET:=$(random_hex)}"
  ADMIN_PASSWORD_GENERATED=${ADMIN_PASSWORD_GENERATED:-0}
  if [ -z "${ADMIN_PASSWORD:-}" ]; then
    ADMIN_PASSWORD=$(random_hex)
    ADMIN_PASSWORD_GENERATED=1
  fi
fi

MYSQL_DATA_INITIALIZED=0
MYSQL_OLD_ROOT_PASSWORD=
if [ -d "$MYSQL_DATA_DIR/mysql" ]; then
  MYSQL_DATA_INITIALIZED=1
  if [ "$GENERATED_ENV_EXISTS" = "0" ]; then
    if [ -z "${MYSQL_ROOT_PASSWORD_INPUT:-}" ]; then
      echo "Existing MySQL data found without $GENERATED_ENV_FILE." >&2
      echo "Provide the previous MYSQL_ROOT_PASSWORD once to migrate this data." >&2
      exit 1
    fi
    MYSQL_OLD_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD_INPUT"
    MYSQL_ROOT_PASSWORD=$(random_hex)
    ADMIN_PASSWORD_GENERATED=0
  fi
fi

export NODE_ENV DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD
export JWT_SECRET JWT_EXPIRES_IN ADMIN_EMAIL ADMIN_PASSWORD ADMIN_USERNAME
export CLIENT_URL REVALIDATE_URL REVALIDATE_SECRET BACKEND_PORT FRONTEND_PORT

write_generated_env() {
  generated_env_tmp="${GENERATED_ENV_FILE}.tmp.$$"
  {
    printf 'MYSQL_ROOT_PASSWORD=%s\n' "$MYSQL_ROOT_PASSWORD"
    printf 'DB_PASSWORD=%s\n' "$DB_PASSWORD"
    printf 'JWT_SECRET=%s\n' "$JWT_SECRET"
    printf 'REVALIDATE_SECRET=%s\n' "$REVALIDATE_SECRET"
    printf 'ADMIN_PASSWORD=%s\n' "$ADMIN_PASSWORD"
    printf 'ADMIN_PASSWORD_GENERATED=%s\n' "$ADMIN_PASSWORD_GENERATED"
  } > "$generated_env_tmp"
  chmod 600 "$generated_env_tmp"
  mv -f "$generated_env_tmp" "$GENERATED_ENV_FILE"
}

write_generated_env

mkdir -p "$MYSQL_DATA_DIR" "$DATA_DIR/uploads" "$DATA_DIR/plugins"
chown -R mysql:mysql "$MYSQL_DATA_DIR"

if [ "$MYSQL_DATA_INITIALIZED" = "0" ]; then
  if find "$MYSQL_DATA_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    echo "MySQL data directory is not empty but is not initialized: $MYSQL_DATA_DIR" >&2
    exit 1
  fi

  echo "Initializing MySQL data directory..."
  mysqld --initialize-insecure --user=mysql --datadir="$MYSQL_DATA_DIR"
fi

echo "Starting MySQL..."
mysqld \
  --user=mysql \
  --datadir="$MYSQL_DATA_DIR" \
  --socket="$MYSQL_SOCKET" \
  --pid-file="$MYSQL_PID_FILE" \
  --bind-address=127.0.0.1 \
  --port="$DB_PORT" \
  --skip-name-resolve \
  > "$MYSQL_DATA_DIR/mysql.log" 2>&1 &
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
    echo "MySQL exited before becoming ready. Check $MYSQL_DATA_DIR/mysql.log." >&2
    exit 1
  fi
  echo "MySQL not ready, retry in 2s..."
  sleep 2
done

echo "MySQL ready. Configuring database and user..."
if [ "$MYSQL_DATA_INITIALIZED" = "0" ]; then
  mysql --protocol=socket --socket="$MYSQL_SOCKET" -uroot <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
else
  MYSQL_LOGIN_PASSWORD="$MYSQL_ROOT_PASSWORD"
  if [ -n "$MYSQL_OLD_ROOT_PASSWORD" ]; then MYSQL_LOGIN_PASSWORD="$MYSQL_OLD_ROOT_PASSWORD"; fi
  mysql --protocol=socket --socket="$MYSQL_SOCKET" -uroot -p"$MYSQL_LOGIN_PASSWORD" <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
fi

echo "Running seed..."
node /app/backend/dist/scripts/seed.js

if [ "$MYSQL_DATA_INITIALIZED" = "0" ] && [ "$ADMIN_PASSWORD_GENERATED" = "1" ]; then
  echo "============================================================"
  echo "kanle 初始管理员账号已创建，请立即保存以下密码："
  echo "用户名: $ADMIN_USERNAME"
  echo "邮箱: $ADMIN_EMAIL"
  echo "初始密码: $ADMIN_PASSWORD"
  echo "密码已保存到 $GENERATED_ENV_FILE"
  echo "============================================================"
fi

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
