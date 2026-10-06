# agent_docker

一个基于 `debian:trixie-slim` 的分层容器环境，主要用于隔离运行 AI CLI 工具，减少对本地开发环境的污染或破坏。

镜像内包含：
- `nodejs` 和 `node-corepack`（通过 `corepack` 固定安装 `pnpm`）
- `bun`
- `uv`
- `git`、`tmux`、`vim`
- `g++`、`cargo`、`cmake`、`ninja`
- `opencode`、MiniMax Code（`mcode`）、Antigravity（`agy`）、`codex` 等 AI CLI

默认通过 `docker compose` 启动，并支持：
- 用环境变量指定容器用户名、UID、GID、HOME
- 给容器用户配置无密码 `sudo`
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

容器内可通过免密码 `sudo` 安装系统包：

```bash
sudo apt-get update
sudo apt-get install -y <package>
```

使用 `--rm` 时，容器内临时安装的软件会在退出后删除；如需永久保留，请添加到 `Dockerfile.base` 的 `apt-get install` 列表中，再重新构建镜像。

`USE_MIRROR=1` 时会同时写入镜像配置：
- `apt` 使用 TUNA Debian 镜像
- `pip` 写入 `/etc/pip.conf`
- `uv` 写入 `/etc/uv/uv.toml`
- `npm`、`pnpm` 写入用户级 `~/.npmrc`
- `bun` 写入用户级 `~/.bunfig.toml`

默认构建不会写这些镜像配置文件。

分层策略：
- `toolbox-base` 使用 `Dockerfile.base` 构建，包含 apt 包、`bun`、`uv`、`pnpm` 等稳定工具链；这一层会正常使用缓存。
- `toolbox-build` 使用 `Dockerfile` 基于 `agent-toolbox-base:trixie` 继续构建，负责创建运行用户、写入用户级镜像配置、配置无密码 `sudo`，并安装 AI CLI，最终产出 `agent-toolbox:trixie`；日常构建使用缓存，更新 AI CLI 时显式加上 `--no-cache`。
- `toolbox` 是纯运行服务，只引用 `agent-toolbox:trixie`，不包含 `build:` 配置；因此执行 `docker compose run toolbox ...` 时不会再进入 Compose 的构建流程。

更新 AI CLI 或刷新最终镜像时，手动重建：

```bash
docker compose build --no-cache toolbox-build
```

这会让 OpenCode、Codex 的 `@latest` 包和 MiniMax Code、Antigravity 的官方安装脚本重新安装构建当时的最新版本。已运行的容器需要退出后重新创建：

```bash
docker compose run --rm toolbox bash
```

MiniMax Code 和 Antigravity 在容器用户下安装，命令 `mcode` 和 `agy` 已加入 `PATH`，构建时会检查版本。`USE_MIRROR=1` 时，MiniMax Code 安装脚本使用其 `cn` 下载镜像。

配置和登录数据通过宿主机目录挂载保留：MiniMax Code 使用 `~/.minimax`，Antigravity 使用 `~/.gemini`，Codex 使用 `~/.codex`，OpenCode 使用 `~/.config/opencode`。MiniMax 的安装目录 `~/.minimax-code` 和 Antigravity 的程序目录 `~/.local/bin` 保留在镜像内，不挂载宿主机目录。

宿主机的 `~/.gitconfig` 以只读方式挂载到容器用户目录，容器沿用宿主机的 Git 姓名、邮箱及其他全局配置，无需重新构建镜像。全局配置请在宿主机修改；容器内仍可使用 `git config --local` 设置单个仓库的配置。

默认运行配置支持 Docker 中的 Codex Linux 沙箱：

```bash
docker compose run --rm toolbox bash
```

此配置无需重建镜像。它沿用普通容器用户和 Docker 默认 capabilities，保留免密码 sudo。为支持嵌套 Bubblewrap 沙箱，它使用自定义 seccomp 配置，放宽 AppArmor 和 Docker 的系统路径遮蔽；没有启用 `privileged`，也没有关闭 Codex 沙箱。这会减少 Docker 外层的保护，不能视为完全隔离；沙箱外的程序可通过 sudo 获得容器内 root 身份，但仍受 Docker 默认 capability 限制。可写挂载和其中的凭据仍需要控制，其他 agent 不会自动获得 Codex 的内层保护。

进入后显式启用工作区权限运行 Codex：

```bash
codex --sandbox workspace-write
```

不调用模型的沙箱自检（成功时退出码为 0）：

```bash
codex sandbox -P :workspace /bin/true
```

详细排查结果、验证范围和 seccomp 来源见 [docker/codex-sandbox.md](docker/codex-sandbox.md)。

`CONTAINER_PROXY` 为空时不会启用代理；只要给这个变量赋值，就会同时传给构建阶段和运行阶段的 `http_proxy`/`https_proxy`。
