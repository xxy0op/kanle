# kanle Docker Compose 部署

## 环境要求

- Linux 服务器
- Docker Engine
- Docker Compose v2
- 一台可被容器访问的 MySQL 5.7/8.0 数据库
- GHCR 中的 `ghcr.io/xxy0op/kanle` 镜像为 Public，或服务器已登录 GHCR

kanle 使用 MySQL 保存业务数据。参考 moments 的单容器部署方式，MySQL 不放进应用容器；可以使用已有的远程 MySQL，也可以在宿主机单独运行 MySQL。

## 快速部署

无需克隆源码仓库。服务器只下载 Compose 文件和环境变量模板：

```bash
mkdir -p /opt/kanle
cd /opt/kanle

curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/xxy0op/kanle/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/xxy0op/kanle/main/.env.example
cp .env.example .env
vim .env
```

至少修改：

```ini
DB_HOST=你的MySQL地址
DB_USER=kanle
DB_PASSWORD=你的MySQL密码
JWT_SECRET=长期稳定的随机密钥
ADMIN_PASSWORD=管理员初始密码
REVALIDATE_SECRET=随机字符串
```

如果 MySQL 在当前宿主机，保留 `DB_HOST=host.docker.internal`，并确保 MySQL 允许来自 Docker 网关的连接。如果 MySQL 在其他服务器，将 `DB_HOST` 改为数据库服务器地址。

启动服务：

```bash
docker compose config
docker compose pull
docker compose up -d
```

默认访问 `http://服务器IP:3000`。如需更换端口，修改 `.env` 中的 `HTTP_PORT`。

## Release 版本部署

推送 `v1.0.0` 标签后，GitHub Actions 会创建 Release，并生成：

- `kanle-1.0.0-deploy.zip`
- `kanle-1.0.0-deploy.tar.gz`
- `kanle-1.0.0-checksums.sha256`

解压部署包后，在 `.env` 中指定版本：

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
docker compose pull
docker compose up -d --force-recreate
```

## 数据和备份

应用容器将 `/var/kanle` 挂载到 `/app/data`，用于保存运行数据、上传文件和音乐插件。MySQL 数据由外部 MySQL 服务负责持久化。

停止服务但保留应用数据：

```bash
docker compose down
```

不要删除 `/var/kanle`，并在升级前备份 MySQL 数据库和 `.env` 文件。

## 检查状态和日志

```bash
docker compose ps
docker compose logs --tail=100 kanle
curl -I http://127.0.0.1:${HTTP_PORT:-3000}/
```

## HTTPS

Compose 直接暴露应用的 3000 端口。生产环境建议在宿主机 Nginx、Caddy、云负载均衡或 CDN 层终止 HTTPS，再反向代理到 `HTTP_PORT`。
