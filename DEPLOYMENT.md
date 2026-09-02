# kanle Docker Compose 部署

## 环境要求

- Linux 服务器
- Docker Engine
- Docker Compose v2
- GHCR 中的 kanle-backend 和 kanle-frontend 镜像为 Public，或服务器已登录 GHCR

## 快速部署

无需克隆源码仓库。服务器只下载 Compose、环境变量模板和 Nginx 配置：

```bash
mkdir -p /opt/kanle/deploy
cd /opt/kanle

curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/xxy0op/kanle/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/xxy0op/kanle/main/.env.example
curl -fsSL -o deploy/nginx.compose.conf https://raw.githubusercontent.com/xxy0op/kanle/main/deploy/nginx.compose.conf

cp .env.example .env
vim .env
```

至少修改 `MYSQL_ROOT_PASSWORD`、`DB_PASSWORD`、`JWT_SECRET`、`ADMIN_PASSWORD` 和 `REVALIDATE_SECRET`。域名部署时将 `CLIENT_URL` 改为站点完整地址，例如 `https://example.com`。

启动服务：

```bash
docker compose config
docker compose pull
docker compose up -d
```

默认通过 `http://服务器IP` 访问。如果修改了 `HTTP_PORT`，访问时带上对应端口。

## Release 版本部署

Release 文件包中包含同样的部署文件。解压到服务器目录后，编辑 `.env` 并设置：

```ini
IMAGE_TAG=1.0.0
```

然后执行：

```bash
docker compose pull
docker compose up -d --force-recreate
```

不设置 `IMAGE_TAG` 时默认拉取 `latest`。

## 更新 latest

```bash
cd /opt/kanle
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/xxy0op/kanle/main/docker-compose.yml
curl -fsSL -o deploy/nginx.compose.conf https://raw.githubusercontent.com/xxy0op/kanle/main/deploy/nginx.compose.conf
docker compose pull
docker compose up -d --force-recreate
```

## 数据持久化

Compose 会保留以下命名卷：

- `mysql-data`：MySQL 数据库
- `backend-uploads`：本地上传文件
- `backend-plugins`：音乐插件

停止服务但保留数据：

```bash
docker compose down
```

不要随意使用 `docker compose down -v`，否则会删除上述数据卷。

更新前建议备份数据库：

```bash
docker compose exec -T mysql sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" "$MYSQL_DATABASE"' > kanle-backup.sql
```

## 检查状态和日志

```bash
docker compose ps
docker compose logs --tail=100 backend
docker compose logs --tail=100 frontend
curl -I http://127.0.0.1:${HTTP_PORT:-80}/
```

## HTTPS

Compose 内置 Nginx 提供 HTTP 入口。生产环境建议在宿主机 Nginx、Caddy、云负载均衡或 CDN 层终止 HTTPS，再将请求转发到 `HTTP_PORT`。
