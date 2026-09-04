# kanle · 朋友圈博客

一个像微信朋友圈一样的个人博客系统。发动态、写文章、评论点赞、音乐播放、邮件通知，所有功能开箱即用。

[![Docker images](https://img.shields.io/github/actions/workflow/status/xxy0op/kanle/publish-image.yml?branch=main&label=docker%20images)](https://github.com/xxy0op/kanle/actions/workflows/publish-image.yml)
[![GHCR](https://img.shields.io/badge/image-GHCR-2496ED?logo=docker&logoColor=white)](https://github.com/xxy0op/kanle/pkgs)

## 功能特性

### 朋友圈动态
- 发图文动态，支持单图/多图（最多 9 图，微信式拼图）
- 发视频动态，弹窗播放器（支持 B 站等外链，全屏/进度条）
- 发 Live Photo 实况图，长按播放视频，默认有声
- 发音乐动态，浮窗播放器可拖拽
- 发链接卡片，自动抓取标题/描述/封面
- 发豆瓣影单卡片，电影/图书/音乐
- 地理位置定位（高德地图）
- 滑动切换图片，双击放大，捏合缩放

### 文章系统
- 富文本编辑器（标题/列表/代码/引用/图片/表情）
- 文章目录、封面、标签
- 归档页时间线，微信式正方形图片拼图

### 豆瓣影单
- 同步豆瓣电影/图书/音乐
- 分页加载 + 骨架屏
- 侧栏展示，支持全部/看过/在看/想看筛选

### 评论互动
- 微信公众号式评论楼层
- 回复折叠，表情包，点赞
- 评论邮件通知（微信聊天式模板）
- 已登录用户免填信息

### 音乐播放器
- 基于 MusicFree 插件
- 支持酷狗/QQ/网易云/酷我/咪咕等音源
- 浮窗卡片可拖拽，歌词面板
- 播放列表，切歌，静音

### 后台管理
- 仪表盘：数据统计概览
- 动态管理：发布/编辑/删除
- 评论管理：审核/回复/删除
- 媒体管理：图片/视频库
- 友链管理：增删改查，随机排序
- 影单管理：豆瓣同步
- 音乐管理：插件/播放列表
- 广告管理：侧栏广告位
- 黑名单：IP 防刷
- 站点设置：SMTP/Cloudflare R2/高德地图/豆瓣/RSS
- 夜间模式适配，移动端侧滑栏

### 其他特性
- **夜间模式** — 手动切换，记忆偏好，全组件适配
- **响应式设计** — 桌面/移动端完美适配
- **Cloudflare R2 存储** — S3 兼容对象存储，未启用时自动回退到本地
- **RSS 订阅** — 自动生成 Feed
- **SEO 优化** — SSR + OG 标签

## 技术栈

| | 技术 |
|---|---|
| 前端 | Next.js 16 · React 19 · Tailwind CSS v4 · Zustand |
| 后端 | Express 5 · Sequelize 6 · TypeScript 6 |
| 数据库 | MySQL 8.0（Docker 内置） |
| 部署 | Docker / Docker Compose |

---

## Docker Compose 部署（推荐）

Compose 默认直接拉取 GHCR 中的 `ghcr.io/xxy0op/kanle:latest` 镜像，服务器不需要保存源码，也不需要安装 Node.js、pnpm 或 PM2。MySQL、后端和前端全部运行在同一个容器内，密钥会在首次启动时自动生成。

### 环境要求

- Linux 服务器
- Docker Engine
- Docker Compose v2
- GHCR 中的 `kanle` 镜像为 Public，或服务器已执行 `docker login ghcr.io`

完整部署步骤见 [`DEPLOYMENT.md`](DEPLOYMENT.md)。

### 当前 `docker-compose.yml`

当前 Docker 部署使用单个应用服务，直接拉取 GHCR 镜像；MySQL、后端和前端在同一容器内运行：

```yaml
services:
  kanle:
    image: ghcr.io/xxy0op/kanle:latest
    pull_policy: always
    container_name: kanle
    restart: always
    ports:
      - 3000:3000
    volumes:
      - /var/kanle:/app/data
```

### 快速开始

不需要克隆整个源码仓库，服务器只需下载部署文件：

```bash
mkdir -p /opt/kanle
cd /opt/kanle

curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/xxy0op/kanle/main/docker-compose.yml
curl -fsSL -o .env.example https://raw.githubusercontent.com/xxy0op/kanle/main/.env.example
```

不需要手动填写数据库密钥、JWT 密钥、重验证密钥或管理员初始密码。首次启动会自动生成这些值，并以 600 权限保存到 `/var/kanle/.env.generated`。

启动服务：

```bash
docker compose config
docker compose pull
docker compose up -d
```

默认访问地址是 `http://服务器IP:3000`。

### 直接使用 Docker 启动

如果不使用 Compose，也可以直接拉取并运行同一个 GHCR 镜像：

```bash
mkdir -p /var/kanle
docker pull ghcr.io/xxy0op/kanle:latest
docker run -d \
  --name kanle \
  --restart always \
  -p 3000:3000 \
  -v /var/kanle:/app/data \
  ghcr.io/xxy0op/kanle:latest
```

直接 Docker 启动与 Compose 使用相同的数据目录、自动密钥和管理员密码日志机制。

首次启动时，容器会初始化 MySQL、创建业务用户和数据表，然后创建管理员账号。管理员初始密码会打印到日志中：`docker compose logs kanle`。生成的密钥和密码会持久化，重启不会变化。

如果从旧版本升级且 `/var/kanle/mysql` 已存在但没有 `/var/kanle/.env.generated`，首次启动需要临时提供旧的 MySQL root 密码，详见 [`DEPLOYMENT.md`](DEPLOYMENT.md)。

### Release 版本部署

每个 `v*` Git 标签会自动生成 Release 部署文件包，包内的 `docker-compose.yml` 会固定使用对应版本镜像：

- `kanle-x.y.z-deploy.zip`
- `kanle-x.y.z-deploy.tar.gz`
- `kanle-x.y.z-checksums.sha256`

解压 Release 文件包后直接执行：

```bash
docker compose pull
docker compose up -d --force-recreate
```

### 更新 latest

```bash
cd /opt/kanle
curl -fsSL -o docker-compose.yml https://raw.githubusercontent.com/xxy0op/kanle/main/docker-compose.yml
docker compose pull
docker compose up -d --force-recreate
```

### 数据和日志

Compose 会把 `/var/kanle` 挂载到容器的 `/app/data`，用于保存 MySQL 数据、上传文件、音乐插件和自动生成的密钥。停止服务但保留应用数据使用 `docker compose down`，不要删除 `/var/kanle`。

管理员初始密码只在首次创建管理员时输出到容器日志；如果日志被清理，只能从备份的 `/var/kanle/.env.generated` 中恢复。

```bash
docker compose ps
docker compose logs --tail=100 kanle
```

更新前建议备份数据库和环境变量。Compose 直接暴露应用的 3000 端口；如需 HTTPS，可在 Docker 外层使用云负载均衡、CDN、Caddy 或其他反向代理。

## 部署方式

项目仅提供 Docker 和 Docker Compose 部署方式。镜像内置 MySQL、后端与 Next.js 前端，服务器无需安装 Node.js、pnpm、PM2 或单独配置 Nginx。

如需 HTTPS，请在 Docker 外层使用云负载均衡、CDN、Caddy 或其他反向代理，将请求转发到 Compose 暴露的 3000 端口。

## 环境变量

### Docker Compose（根目录 `.env`）

Docker Compose 不再要求手动配置密钥。首次启动时会自动生成并保存到 `/var/kanle/.env.generated`。

普通 Docker 部署无需准备 `.env` 或修改任何参数；密钥和管理员初始密码由容器首次启动时自动生成。

完整模板见 [`.env.example`](.env.example)。

### Docker 镜像内部默认值

| 变量 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| `DB_HOST` | `127.0.0.1` | 容器内 MySQL 地址 |
| `DB_PORT` | `3306` | MySQL 端口 |
| `DB_USER` | 自动生成 | MySQL 业务用户名 |
| `DB_PASSWORD` | 自动生成 | MySQL 业务密码 |
| `DB_NAME` | `moment_blog` | 数据库名 |
| `JWT_SECRET` | 自动生成 | JWT 密钥 |
| `JWT_EXPIRES_IN` | `7d` | Token 过期时间 |
| `ADMIN_EMAIL` | `admin@kanle.net` | 初始管理员邮箱，仅首次创建生效 |
| `ADMIN_PASSWORD` | 自动生成 | 初始管理员密码，首次启动日志可查看 |
| `ADMIN_USERNAME` | `admin` | 管理员用户名 |
| `CLIENT_URL` | `http://localhost:3000` | 前端地址 |
| `REVALIDATE_URL` | 使用 `CLIENT_URL` | Next.js 按需重验证地址 |
| `REVALIDATE_SECRET` | 自动生成 | 按需重验证密钥 |

### 前端（`frontend/.env.local`）

| 变量 | 必填 | 说明 |
|---|---|---|
| `NEXT_PUBLIC_API_URL` | 是 | 后端 API 地址，默认 `/api`（相对路径，通过 rewrites 代理，通用） |
| `BACKEND_URL` | Docker 内部默认值 | Next.js rewrites 代理目标 |
| `NEXT_PUBLIC_SITE_URL` | 否 | 站点 URL（用于 Cravatar 默认头像，不设则回退 wavatar） |
| `NEXT_PUBLIC_TWIKOO_ENV_ID` | 否 | Twikoo 评论系统环境 ID |
| `REVALIDATE_SECRET` | 否 | 须与后端一致，仅在 Next.js 服务端使用 |

> `NEXT_PUBLIC_API_URL=/api` 是相对路径，换域名后**不需要重新构建**。

## 后台配置

登录后台管理面板（`/admin`）后设置以下功能：

| 功能 | 位置 | 说明 |
|---|---|---|
| SMTP 邮件 | 站点设置 → 邮件配置 | SMTP 服务器、端口、发件箱、可发送测试邮件 |
| Cloudflare R2 存储 | 云端存储 | Account ID、S3 Access Key、Bucket、公开访问域名；未启用时使用本地存储 |
| 高德地图 | 站点设置 → 高德地图配置 | JS API Key + Web 服务 Key，[高德开放平台](https://lbs.amap.com/)申请 |
| 音乐插件 | 音乐管理 → 插件管理 | 上传 `.js` 插件或填写订阅 URL，支持酷狗/QQ/网易云/酷我 |
| 豆瓣影单 | 站点设置 → 豆瓣配置 | 豆瓣 ID，自动同步电影/图书/音乐 |
| 自动播放 | 音乐管理 → 进入网站自动播放 | 开启后访客进入网站自动播放歌单音乐 |
| 站点信息 | 站点设置 | 站点名称、Favicon、背景图、备案号、夜间模式、RSS |

## 常见问题

<details>
<summary>换了域名需要重新构建前端吗？</summary>

**不需要。** `NEXT_PUBLIC_API_URL=/api` 是相对路径，通过 Next.js rewrites 代理到容器内后端，换域名/IP 无需重新构建镜像。
</details>

<details>
<summary>发动态后刷新页面没看到更新？</summary>

检查后端 `.env` 的 `REVALIDATE_SECRET` 与前端服务端环境中的 `REVALIDATE_SECRET` 是否一致。Compose 部署还要确保后端能通过内部地址访问前端。
</details>

<details>
<summary>忘记管理员密码？</summary>

```bash
docker compose logs kanle | grep "管理员初始密码"
```
密码只在首次创建管理员时输出；如果日志已清理，请从宿主机 `/var/kanle/.env.generated` 读取并妥善保管。
</details>

<details>
<summary>MySQL 连不上？</summary>

- 确认容器正在运行：`docker compose ps`
- 查看数据库初始化日志：`docker compose logs --tail=200 kanle`
- 首次启动时不要删除宿主机 `/var/kanle` 数据目录
</details>

<details>
<summary>上传的图片显示不出来？</summary>

- 确认宿主机 `/var/kanle` 已挂载且容器有写权限
- 如启用了 R2，确认公开访问域名可访问，并在后台测试 R2 连接
- 如使用 R2 自定义域名，确认该域名已绑定到对应 Bucket
</details>

<details>
<summary>前端构建时内存不足？</summary>

```bash
export NODE_OPTIONS="--max-old-space-size=2048"
pnpm build
```
</details>

<details>
<summary>如何查看日志？</summary>

```bash
docker compose logs --tail=200 -f kanle
```
</details>

<details>
<summary>如何修改前端端口？</summary>

编辑 `docker-compose.yml` 的 `ports` 映射，例如改为 `8080:3000`，然后执行 `docker compose up -d --force-recreate`。
</details>

## 开发

```bash
# 后端（热重载）
cd backend && pnpm dev

# 前端（热重载）
cd frontend && pnpm dev
```

项目使用 `sequelize.sync()` 自动创建表，无需手动迁移。

## License

[MIT](LICENSE)

Copyright (c) 2026 zilinnb
