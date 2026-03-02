# Air-Gapped Codex + llama.cpp

**\[ [English](README.md) ]**

---

> **你的运维智能体。离线。一个文件夹。**  
> *把可携带的 AI 带进保密间——无云、无外网、不妥协。*

---

## 为什么需要它

隔离环境做运维：上不了网、带不了设备，文档查不了、AI 问不了；K8s 命令长、配置多，只能死记或打印带进去——又慢又容易错。**拷进一个文件夹**，在本地离线跑 Codex 级智能体：说一句「帮我查某某命名空间下异常 Pod」，自动生成命令、执行并给建议。无外网、无云。**不能联网的环境里，它就是你的离线运维专家。**

---

## 技术上它是什么

**Air-Gapped Codex + llama.cpp** 是一个**单目录、可携带**的套件：

- 用 [llama.cpp](https://github.com/ggml-org/llama.cpp) 在本地跑**本地大模型**——**仅 CPU 推理**，无需 GPU。
- 提供 **OpenAI 兼容的 HTTP API**，让 **[Codex CLI](https://developers.openai.com/codex)**（OpenAI 的编程/运维智能体）连到这台本地模型，在**完全离线**的情况下获得和用云端 API 时同等的智能体体验。
- 只需在**有网络的机器上**做一次准备（构建 llama.cpp、下载 GGUF 模型、生成配置），然后把**整个目录**拷到合规介质上带进工作区即可。目标环境**不需要任何外网**。

用于**部署、配置、写 runbook、排障**——不用出房间、不碰云。

**默认模型：** [千问 3.5 最新版](https://huggingface.co/Qwen/Qwen3.5-2B)（Qwen 3.5 latest）— CPU 与 GPU 均使用该模型（CPU 为 GGUF，GPU 为 Hugging Face 格式）。

---

## 快速开始（三步）

在项目目录下打开终端执行。

### 1. 一次性准备（在能联网的机器上）

```bash
./bootstrap.sh
```

会下载 llama.cpp 预编译二进制（Linux x64 CPU）、构建 **codex-proxy**、下载默认 CPU 模型（Qwen3.5-2B GGUF，见下方「可选：不同模型」中的仓库名）并生成指向 proxy 的配置。看到 `[bootstrap] Done. Next: ...` 即完成。

### 2. 启动后端（一个终端，保持打开）

**在一个终端中执行并保持打开：**

```bash
./start.sh
```

会启动模型服务（默认 CPU；若做过 `USE_VLLM=1` 的 bootstrap 则用 GPU）和 **codex-proxy**（28081）。看到 "Codex proxy running at..." 即就绪。首次启动会加载模型，稍等即可。

### 3. 运行 Codex（在另一个终端）

**再开一个终端**，进入同一项目目录后执行：

```bash
./run-codex.sh exec "帮我写一个简单的 Web 应用的 Kubernetes Deployment YAML"
```

Codex 会使用本地模型。把引号里的内容换成你的真实任务——写配置、写脚本、排查问题都可以。

**用完后关服务：** 在运行服务的终端按 **Ctrl+C**，或在任意终端执行 `./stop.sh`。

---

## 拷进隔离/保密工作区

1. 在**能联网的机器**上执行 `./bootstrap.sh` 并等待完成。  
2. **拷盘前**确认目录内包含：
   - `models/` — 已下载的模型
   - `.venv/` — Python 虚拟环境
   - `.codex/` — 配置与 model_info
   - `llama_bin/` — llama.cpp 二进制
   - 已构建的 `codex-proxy`（或拷源码后在目标机执行 `make proxy`）
   - 可选：执行 `./scripts/check-portable.sh` 做一次自检。
3. 将**整个**项目目录拷到合规介质上。  
4. 在工作区机器上（无需网络）：在一个终端运行 `./start.sh`（保持打开），在另一个终端运行 `./run-codex.sh exec "你的任务"`。

无云、无 API Key、无外网。

---

## 环境要求

| 要求 | 说明 |
|------|------|
| **uv** | [安装 uv](https://docs.astral.sh/uv/getting-started/installation/)（Python/环境管理）。验证：`uv --version`。 |
| **Codex CLI** | 在 **Cursor** 中：Preferences → Advanced → **Install CLI**；或通过 npm 安装。验证：`codex --version`。 |
| **curl** | 执行 bootstrap 时用于下载 llama.cpp 二进制。无需本地编译或 GPU。 |

---

## 常用命令一览

| 命令 | 作用 |
|------|------|
| `./bootstrap.sh` | 一次性准备（仅需执行一次，需要联网）。 |
| `./start.sh` | 启动后端与 proxy（CPU 或已配置的 GPU）。保持该终端开启。 |
| `./stop.sh` | 停止后端与 proxy。 |
| `./run-codex.sh exec "任务"` | 用 Codex 执行任务（请在**第二个**终端执行）。 |
| `./test-api.sh` | 快速检查服务是否正常响应。 |

也可直接使用 `./start-llama-server.sh` / `./stop-llama-server.sh`（CPU）或 `./start-vllm.sh` / `./stop-vllm.sh`（GPU）显式选择后端。

请始终在**本项目目录**下执行 `./run-codex.sh`，这样 Codex 会使用本项目的配置与状态，不会和 `~/.codex` 混用。

---

## 使用说明

### 如何使用（日常流程）

**最简单（一条命令启停）：**

1. **仅首次：** 执行 `./bootstrap.sh`（需联网）；若用 GPU，执行 `USE_VLLM=1 ./bootstrap.sh`。
2. **启动：** 执行 `./start.sh`（保持该终端不关）。默认用 CPU；若已配置 vLLM 则用 GPU。
3. **在另一个终端：** 执行 `./run-codex.sh exec "你的任务"`。
4. **用完后：** 执行 `./stop.sh`，或在服务所在终端按 Ctrl+C。

**或显式选择后端：**

- **CPU：** `./start-llama-server.sh` / `./stop-llama-server.sh`
- **GPU：** `./start-vllm.sh` / `./stop-vllm.sh`

若 vLLM 报 **CUDA 显存不足**，可降低上下文或显存占用：`VLLM_MAX_MODEL_LEN=32768 VLLM_GPU_MEM_UTIL=0.85 ./start-vllm.sh`

---

### 如何切换模型

**CPU（llama.cpp）— GGUF 模型：**

- 默认 CPU 模型：[Qwen/Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B) 的 GGUF 版本 — [bartowski/Qwen_Qwen3.5-2B-GGUF](https://huggingface.co/bartowski/Qwen_Qwen3.5-2B-GGUF)（llama.cpp）。
- 要换其他 Hugging Face 仓库（GGUF 或兼容格式）：用新的仓库 id 重新执行 bootstrap，会下载新模型并更新 `.codex/config.toml` 与 `.codex/model_info`：

  ```bash
  HF_MODEL_REPO_ID=owner/repo-name ./bootstrap.sh
  ```

- 然后照常启动：`./start-llama-server.sh`。新模型会从 `models/<repo-name>/` 加载。

**GPU（vLLM）— HuggingFace 格式（同一模型）：**

- 使用 `USE_VLLM=1` 时的默认 vLLM 模型：[Qwen/Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B)（全精度）。启动时默认最多 1 并发、自动检测上下文长度、高显存占用 (0.95)。
- 要换其他 Hugging Face 模型：带 vLLM 重新 bootstrap 并指定 `VLLM_MODEL`：

  ```bash
  VLLM_MODEL=owner/repo-name USE_VLLM=1 ./bootstrap.sh
  ```

- 然后启动 vLLM：`./start-vllm.sh`。vLLM 会使用 `.codex/model_info` 里的 `VLLM_MODEL`。

**说明：** CPU 使用 GGUF 格式（量化，供 llama.cpp 使用）；GPU 使用 HuggingFace safetensors 格式（全精度，供 vLLM 使用）。两者默认均为 **Qwen3.5-2B**，同一模型、不同格式。GPU 上无需量化。

---

### 如何在 GPU 与 CPU 之间切换

同一项目下可以**任选** llama.cpp（CPU）**或** vLLM（GPU）运行；同一时间只运行一个后端（都占 28080）。

**从 GPU（vLLM）切回 CPU（llama.cpp）：**

1. 先停掉 GPU 后端：`./stop-vllm.sh`。
2. 确认至少做过一次 **CPU** bootstrap（即已有 `models/` 下的 GGUF 和 `.codex/model_info` 里的 `MODEL_DIR`、`LLAMA_SERVER`）。若从未做过普通 bootstrap，先执行一次：`./bootstrap.sh`（会下载 llama.cpp 二进制和默认 GGUF 模型）。
3. 启动 CPU 后端：`./start-llama-server.sh`。
4. 照常使用 Codex：`./run-codex.sh exec "..."`。

若 Codex 仍带着 vLLM 的模型名（请求报错或不对），可重新做一次不带 vLLM 的 bootstrap 以恢复 config 中的 GGUF 模型名：`./bootstrap.sh`。

**从 CPU（llama.cpp）切到 GPU（vLLM）：**

1. 先停掉 CPU 后端：`./stop-llama-server.sh`。
2. 确认已安装 vLLM 并设好 vLLM 模型。若从未做过带 vLLM 的 bootstrap，执行：`USE_VLLM=1 ./bootstrap.sh`（或 `VLLM_MODEL=owner/repo USE_VLLM=1 ./bootstrap.sh`）。
3. 启动 GPU 后端：`./start-vllm.sh`。脚本会把 `.codex/config.toml` 里的模型名改成 vLLM 的，保证请求一致。
4. 照常使用 Codex：`./run-codex.sh exec "..."`。

**小结：**

| 想用哪种后端 | 操作 |
|--------------|------|
| CPU（llama.cpp） | 若之前在用 vLLM 先 `./stop-vllm.sh`，再 `./start-llama-server.sh`。必要时执行 `./bootstrap.sh` 恢复 config 模型名。 |
| GPU（vLLM）      | 若之前在用 llama 先 `./stop-llama-server.sh`，再 `./start-vllm.sh`。 |

---

### 端口与调参（可选）

**端口：** 后端默认 28080，代理 28081。可改为例如 `LLAMA_PORT=28081 ./start-llama-server.sh`（或 `VLLM_PORT=28081 ./start-vllm.sh`），若改端口，运行 Codex 时需与之一致。

**CPU 上下文/线程：** 上下文大小根据可用内存**自动检测**（2048–32768）。覆盖：`LLAMA_CTX_SIZE=16384`。线程数根据 `nproc` 自动检测；覆盖：`LLAMA_THREADS=8`。示例：`LLAMA_CTX_SIZE=16384 LLAMA_THREADS=8 ./start-llama-server.sh`。

**GPU 调参：** 上下文长度由 vLLM 根据 GPU 显存自动检测。覆盖参数：`VLLM_MAX_MODEL_LEN=32768`、`VLLM_GPU_MEM_UTIL=0.85`、`VLLM_MAX_NUM_SEQS=2`。

---

## 常见问题

| 现象 | 处理 |
|------|------|
| `.codex/config.toml not found` | 先执行 `./bootstrap.sh`。 |
| “Model server is not reachable” 或 Codex 无响应 | 先启动服务：`./start-llama-server.sh`，等就绪后再执行 `./run-codex.sh exec "..."`。 |
| 找不到 Codex CLI | 在 Cursor 中安装（Preferences → Advanced → Install CLI）或通过 npm 安装，并重新打开终端。 |
| 端口 28080 被占用 | 执行 `./stop-llama-server.sh`，等几秒再试；或换端口：`LLAMA_PORT=28081 ./start-llama-server.sh` 与 `LLAMA_PORT=28081 ./run-codex.sh exec "..."`。 |
| 400 `'type' of tool must be 'function'` | Codex 下发的工具被 llama-server 拒绝。可用 `USE_CODEX_PROXY=1 ./start-llama-server.sh` 并让配置走代理（见文档）。 |
| 找不到 llama-server | 先执行 `./bootstrap.sh` 下载预编译二进制。 |

---

## 项目宪章与文档

- **[CHARTER.md](CHARTER.md)** — 项目初衷、目标用户与开发边界（宪章）。
- **[CHANGELOG.md](CHANGELOG.md)** — 发布历史。当前版本：**0.4.0**（见 [VERSION](VERSION)）。
- **[docs/README.md](docs/README.md)** — 技术说明（架构、bootstrap、配置）。
- **[README.md](README.md)** — 英文说明。

---

## 目录结构（参考）

| 路径 | 说明 |
|------|------|
| `bootstrap.sh` | 一次性准备脚本。 |
| `start-llama-server.sh` | 启动 llama.cpp（CPU）+ proxy。 |
| `stop-llama-server.sh` | 停止 llama-server 与 proxy。 |
| `start-vllm.sh` | 启动 vLLM（GPU）+ proxy（需在 bootstrap 时加 `USE_VLLM=1`）。 |
| `stop-vllm.sh` | 停止 vLLM 与 proxy。 |
| `run-codex.sh` | 使用本项目配置运行 Codex。 |
| `test-api.sh` | 测试服务是否响应。 |
| `models/`、`.venv/`、`.codex/`、`llama_bin/` | 由 bootstrap 生成；迁移时需一并拷贝。 |

**Make：** `make deps`（等同于 bootstrap）、`make clean`（清理生成内容）、`make test`（运行检测，需已安装并可用 `codex`）。GPU 路径：`USE_VLLM=1 ./bootstrap.sh` 后执行 `./start-vllm.sh`。

---

## 许可证

MIT。见 [LICENSE](LICENSE)。
