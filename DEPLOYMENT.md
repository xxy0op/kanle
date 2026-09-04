# kanle Docker Compose 部署

## 环境要求

- Linux 服务器
- Docker Engine
- Docker Compose v2
- GHCR 中的 `ghcr.io/xxy0op/kanle` 镜像为 Public，或服务器已登录 GHCR

kanle 的 Docker 镜像内置 MySQL 8、后端和 Next.js 前端。Compose 只启动一个 `kanle` 容器，不需要在宿主机单独安装 MySQL、Node.js、pnpm 或 PM2。

## 快速部署

无需克隆源码仓库。服务器只下载 Compose 文件和环境变量模板：

```bash
mkdir -p /opt/kanle
cd /opt/kanle

curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/xxy0op/kanle/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/xxy0op/kanle/main/.env.example
```

不需要手动填写数据库密码、JWT 密钥、重验证密钥或管理员密码。首次启动时容器会自动生成这些值，并以 600 权限保存到 `/var/kanle/.env.generated`。

启动服务：

```bash
docker compose config
docker compose pull
docker compose up -d
```

默认访问地址为 `http://服务器IP:3000`。

首次启动时，容器会初始化 MySQL 数据库、创建业务用户和数据表，然后创建初始管理员账号。管理员初始密码会输出到日志：

```bash
docker compose logs kanle
```

生成的密钥和密码会持久化，容器重启后不会变化。

如果是从旧版本升级，且 `/var/kanle/mysql` 已存在但没有 `/var/kanle/.env.generated`，需要首次启动时临时提供旧的 MySQL root 密码：

```bash
docker compose run --rm -e MYSQL_ROOT_PASSWORD='旧的root密码' kanle
```

迁移完成后按 `Ctrl+C` 停止该命令，再执行 `docker compose up -d`。之后新的 root 密钥和其他密钥都会自动保存。

## Release 版本部署

推送 `v1.0.0` 标签后，GitHub Actions 会创建 Release。Release 包中的 `docker-compose.yml` 会固定使用对应版本镜像：

- `kanle-1.0.0-deploy.zip`
- `kanle-1.0.0-deploy.tar.gz`
- `kanle-1.0.0-checksums.sha256`

解压 Release 文件包后直接执行：

```bash
docker compose pull
docker compose up -d --force-recreate
```

## 更新 latest

```bash
cd /opt/kanle
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/xxy0op/kanle/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/xxy0op/kanle/main/.env.example
docker compose pull
docker compose up -d --force-recreate
```

## 数据和备份

Compose 将宿主机 `/var/kanle` 挂载到容器 `/app/data`，其中包括：

- `/var/kanle/mysql`：MySQL 数据库
- `/var/kanle/uploads`：上传文件
- `/var/kanle/plugins`：音乐插件
- `/var/kanle/.env.generated`：自动生成的密钥和管理员初始密码

停止服务但保留数据：

```bash
docker compose down
```

不要删除 `/var/kanle`。更新前建议备份数据库、上传文件、插件和 `.env.generated` 文件。

## 检查状态和日志

```bash
docker compose ps
docker compose logs --tail=100 kanle
curl -I http://127.0.0.1:3000/
```

## HTTPS

Compose 直接暴露应用的 3000 端口。生产环境建议在宿主机 Nginx、Caddy、云负载均衡或 CDN 层终止 HTTPS，再反向代理到 3000 端口。
