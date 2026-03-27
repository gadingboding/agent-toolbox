# agent_docker

一个基于 `debian:trixie-slim` 的分层容器环境，主要用于隔离运行 AI CLI 工具，减少对本地开发环境的污染或破坏。

镜像内包含：
- `nodejs` 和 `node-corepack`（通过 `corepack` 固定安装 `pnpm`）
- `bun`
- `uv`
- `git`、`tmux`、`vim`
- `g++`、`cargo`、`cmake`
- `opencode`、`qwen`、`gemini`、`codex` 等 AI CLI

默认通过 `docker compose` 启动，并支持：
- 用环境变量指定容器用户名、UID、GID、HOME
- 给该用户配置无密码 `sudo`
- 通过构建参数固定 `bun`、`uv`、`pnpm` 版本
- 按需统一开启镜像配置
- 将镜像拆为稳定的 `base` 层、最终镜像构建服务和纯运行服务

常用变量：

```env
CONTAINER_PROXY=
CONTAINER_USER=dev
CONTAINER_UID=1000
CONTAINER_GID=1000
CONTAINER_HOME=/home/dev
USE_MIRROR=0
BUN_VERSION=1.3.11
UV_VERSION=0.11.2
PNPM_VERSION=10.33.0
```

示例：

首次构建基础层和最终镜像：

```bash
docker compose build toolbox-build
```

启动一次交互式运行容器：

```bash
docker compose run --rm toolbox bash
```

启用代理构建：

```bash
CONTAINER_PROXY=http://host.docker.internal:<port> docker compose build toolbox-build
```

关闭代理构建：

```bash
CONTAINER_PROXY= docker compose build toolbox-build
```

启用 TUNA 镜像构建：

```bash
USE_MIRROR=1 docker compose build toolbox-build
```

容器内安装系统包：

```bash
sudo apt-get update
sudo apt-get install -y <package>
```

`USE_MIRROR=1` 时会同时写入镜像配置：
- `apt` 使用 TUNA Debian 镜像
- `pip` 写入 `/etc/pip.conf`
- `uv` 写入 `/etc/uv/uv.toml`
- `npm`、`pnpm` 写入用户级 `~/.npmrc`
- `bun` 写入用户级 `~/.bunfig.toml`

默认构建不会写这些镜像配置文件。

分层策略：
- `toolbox-base` 使用 `Dockerfile.base` 构建，包含 apt 包、`bun`、`uv`、`pnpm` 等稳定工具链；这一层会正常使用缓存。
- `toolbox-build` 使用 `Dockerfile` 基于 `agent-toolbox-base:trixie` 继续构建，负责创建运行用户、写入用户级镜像配置、配置无密码 `sudo`，并安装 AI CLI，最终产出 `agent-toolbox:trixie`；这一层在 compose 中设置了 `build.no_cache: true`，所以每次手动构建都会重新执行最终层安装步骤。
- `toolbox` 是纯运行服务，只引用 `agent-toolbox:trixie`，不包含 `build:` 配置；因此执行 `docker compose run toolbox ...` 时不会再进入 Compose 的构建流程。

更新 AI CLI 或刷新最终镜像时，手动重建：

```bash
docker compose build toolbox-build
```

这会让 `@latest` 的 AI CLI 按构建当时的最新版本重新安装，但不会影响 `toolbox` 的日常运行命令。

`CONTAINER_PROXY` 为空时不会启用代理；只要给这个变量赋值，就会同时传给构建阶段和运行阶段的 `http_proxy`/`https_proxy`。

