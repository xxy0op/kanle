## 2026-09-02 13:42 - 添加 Docker Compose 部署

Status: Completed

Progress:
- Completed: 新增 MySQL、后端、前端和 Nginx 的 Docker Compose 部署配置；为上传文件和音乐插件配置持久化卷；移除客户端携带重验证服务端密钥的逻辑，并增加 Compose 内网重验证地址；补充部署文档和环境变量示例；为 standalone 缓存目录补充 `node` 用户归属并关闭 Compose Nginx 前端代理缓冲。
- In progress: 无。
- Not started: 本机 Docker 镜像构建和容器启动（当前环境未安装 Docker）。
- Verification: 后端 `npm ci`、`npm run build` 通过；前端 `npm ci`、最终 `npm run build` 及 standalone 静态资源复制通过；Compose YAML、服务、持久化卷与必填变量映射通过 `js-yaml` 检查；standalone 文件归属与 Nginx 流式代理配置检查通过；`git diff --check` 通过。全量 ESLint 仍有仓库原有的 173 个错误和 73 个警告。
- Unresolved bugs / risks: 当前环境无法直接运行 Docker Compose；需在安装 Docker 的主机上执行 `docker compose up -d --build` 验证镜像构建和首次数据库初始化。全量 ESLint 问题未纳入本次部署改动。
- Files changed: .env.example, docker-compose.yml, backend/Dockerfile, backend/.dockerignore, backend/src/utils/revalidate.ts, frontend/Dockerfile, frontend/.dockerignore, frontend/src/components/PostList.tsx, frontend/src/components/profile/ProfileTimeline.tsx, deploy/nginx.compose.conf, README.md, backend/.env.example, logs.md

## 2026-09-02 15:24 - 切换为远程镜像部署并自动发布 Release

Status: In progress

Progress:
- Completed: 对比参考 moments 项目的 GHCR 镜像、Compose 和 GitHub Actions 发布方式。
- In progress: 将 kanle Compose 改为直接拉取 GHCR 镜像，并添加多架构镜像与版本文件包发布流程。
- Not started: 校验 YAML/工作流结构并更新部署文档。
- Verification: 尚未开始。
- Unresolved bugs / risks: GHCR 包公开状态和 GitHub Actions 实际运行结果需在远程仓库确认。
- Files changed: logs.md

## 2026-09-02 18:01 - 完成 GHCR 远程镜像与 Release 部署包

Status: Completed

Progress:
- Completed: 将 Compose 的后端和前端从本地 `build` 切换为 `ghcr.io/xxy0op/kanle-backend` 与 `ghcr.io/xxy0op/kanle-frontend`，加入 `pull_policy: always` 和 `IMAGE_TAG` 版本选择；新增无需克隆源码的 `DEPLOYMENT.md`。
- Completed: 新增 GitHub Actions，多架构构建并发布 GHCR 镜像；推送 `v*` 标签时自动生成 ZIP、TAR.GZ 和 SHA256 校验文件并上传 GitHub Release。
- In progress: 无。
- Not started: GitHub Actions 远程运行及 GHCR 容器包 Public 状态确认。
- Verification: Compose 与两个 workflow 均通过 `js-yaml` 解析；确认 Compose 无应用服务 `build` 配置且远程镜像、`IMAGE_TAG`、持久化卷均存在；部署文档已移除 Compose 的本地构建命令；`git diff --check` 通过。
- Unresolved bugs / risks: 当前环境无法直接访问 GitHub Actions 或验证 GHCR 镜像是否已成功发布；首次推送后请确认 `ghcr.io/xxy0op/kanle-backend` 和 `ghcr.io/xxy0op/kanle-frontend` 为 Public，或在服务器执行 `docker login ghcr.io`。
- Files changed: docker-compose.yml, .env.example, DEPLOYMENT.md, README.md, .github/workflows/publish-image.yml, .github/workflows/release-bundle.yml, logs.md

## 2026-09-02 19:29 - 统一为单容器远程镜像部署

Status: Completed

Progress:
- Completed: 根据用户提供的 Compose 示例和 moments 参考项目，将 Compose、GHCR 工作流和 Release 文件包调整为单一 `kanle` 应用镜像；应用数据统一持久化到 `/var/kanle:/app/data`；保留现有 MySQL 作为外部数据库；移除旧的四容器 Compose 部署文件。
- In progress: 无。
- Not started: 无。
- Verification: Compose 和两个 GitHub Actions workflow 通过 `js-yaml` 解析；确认 Compose 仅包含 `kanle` 服务、远程 GHCR 镜像、`pull_policy: always`、固定容器名、3000 端口和 `/var/kanle:/app/data` 挂载；`docker-entrypoint.sh` 通过 shell 语法检查；根 Dockerfile、Release 包命令和文档检查通过；`git diff --check` 通过。
- Unresolved bugs / risks: kanle 当前后端依赖 MySQL，不能在不迁移数据库架构的情况下直接变成 moments 式内置 SQLite；本次采用单应用容器 + 外部 MySQL。当前环境没有 Docker，无法执行真实镜像构建和启动。
- Files changed: docker-compose.yml, Dockerfile, docker-entrypoint.sh, .dockerignore, .env.example, DEPLOYMENT.md, README.md, .github/workflows/publish-image.yml, .github/workflows/release-bundle.yml, logs.md

## 2026-09-03 00:04 - 发布 v1.0.0 Release

Status: Completed

Progress:
- Completed: 确认远端 `main` 已包含 README 和单容器 Docker 部署配置；创建并推送 `v1.0.0` 标签。
- Completed: GitHub Actions 成功创建 `v1.0.0` Release，并上传 ZIP、TAR.GZ 和 SHA256 校验文件；多架构 GHCR 镜像工作流执行成功。
- In progress: 无。
- Not started: 无。
- Verification: Release 地址为 `https://github.com/xxy0op/kanle/releases/tag/v1.0.0`；3 个 Release 资产已确认存在；镜像工作流 `33651739199` 成功；远端 README 已确认包含 Docker Compose、GHCR、Release 和 `/var/kanle` 内容。
- Unresolved bugs / risks: 未授权访问 GHCR registry 返回 401，无法从当前环境确认容器包 Public 状态；若包未公开，部署服务器需先执行 `docker login ghcr.io`。
- Files changed: logs.md；远端已发布标签 `v1.0.0` 和 Release 资产。

## 2026-09-03 00:39 - 将 Compose 完整配置同步到 README

Status: Completed

Progress:
- Completed: 对照当前 `docker-compose.yml` 检查 README Docker Compose 部署章节，并补充当前单容器 Compose 完整配置代码块。
- In progress: 无。
- Not started: 无。
- Verification: README 中的 YAML 代码块与当前 `docker-compose.yml` 内容逐字一致；README 和日志空白检查通过。
- Unresolved bugs / risks: 尚未开始。
- Files changed: README.md, logs.md

## 2026-09-03 01:17 - 将 MySQL 整合到单容器

Status: Completed

Progress:
- Completed: 将 MySQL 8、后端和前端整合到同一个 GHCR 镜像；数据库、上传文件和插件统一持久化到 `/app/data`；Compose 改为只启动一个 `kanle` 服务。
- In progress: 无。
- Not started: 无。
- Verification: `docker-entrypoint.sh` shell 语法检查通过；Compose YAML 检查通过，确认单服务、内部 MySQL、`pull_policy: always`、3000 端口和 `/var/kanle:/app/data`；README 中的 Compose 配置与文件完全一致；后端 `npm run build` 和前端 `npm run build` 通过。
- Unresolved bugs / risks: 当前环境没有 Docker，无法执行真实镜像构建、MySQL 首次初始化和容器启动验证；发布后需确认 GHCR 镜像构建成功。
- Files changed: docker-compose.yml, Dockerfile, docker-entrypoint.sh, .env.example, DEPLOYMENT.md, README.md, logs.md
