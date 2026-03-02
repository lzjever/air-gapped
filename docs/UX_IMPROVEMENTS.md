# UX & 使用逻辑改进建议

从「用户使用越简单越好」出发的检查与建议。

---

## 一、当前体验中的主要摩擦

### 1. 两套「启动/停止」增加心智负担

- **现状**：CPU 用 `start-llama-server.sh` / `stop-llama-server.sh`，GPU 用 `start-vllm.sh` / `stop-vllm.sh`。用户要先判断「这次用 CPU 还是 GPU」，再选脚本。
- **问题**：新用户容易搞混；切到离线环境时也容易记错该跑哪一个。
- **建议**：
  - **方案 A（推荐）**：提供**统一入口** `./start.sh`：自动检测是否有 GPU / 是否做过 vLLM bootstrap，有则 `start-vllm`，否则 `start-llama-server`。`./stop.sh` 同理（先尝试停 vLLM，再停 llama）。日常只记「start / stop」即可。
  - **方案 B**：保留两个脚本，但在 README 和脚本里的首行注释写死「大多数情况：无 GPU 用 start-llama-server，有 GPU 用 start-vllm」，并在 `./start-llama-server.sh` 开头若检测到 `VLLM_MODEL` 且存在 GPU 时打印一行提示：「检测到已配置 vLLM，如需 GPU 加速可运行 ./start-vllm.sh」。

### 2. 首次使用需要记住「先 bootstrap 再 start」

- **现状**：必须先 `./bootstrap.sh`（有网），之后才能 `./start-*.sh`。若用户直接运行 start，会看到「Run ./bootstrap.sh first」。
- **问题**：错误信息清晰，但不会自动补救；新用户可能不知道要回到有网环境做 bootstrap。
- **建议**：
  - start 脚本在检测到未 bootstrap 时，**多给一步**：打印「若当前无网络，请在有网络的机器上执行 ./bootstrap.sh 后，将整个目录拷到本机再运行 ./start.sh」。
  - 可选：`./start.sh` 在「无 .codex/model_info」时，若当前有网络，询问是否执行 `./bootstrap.sh`（y/n），减少一步手动操作（实现成本较高，可作后续迭代）。

### 3. CPU/GPU 默认模型不一致且文档易混

- **现状**：CPU 默认是 GGUF 仓库（bartowski/Qwen_Qwen3.5-2B-GGUF），vLLM 默认是 HF 仓库（Qwen/Qwen3.5-2B）。README 里「默认模型」若只写一个名字，容易让人以为两边是同一个模型。
- **问题**：换模型、拷盘、重装时容易搞错「我到底在用哪个模型」。
- **建议**：
  - README 明确写成两行：「CPU 默认：…（GGUF）」「GPU 默认：…（HuggingFace）」，并注明「同一模型 Qwen3.5-2B，格式不同」。
  - Quick start 里第一步 bootstrap 的说明里，写清「会下载 CPU 用模型（GGUF）并生成配置」，避免和 GPU 模型混淆。

### 4. 「两个终端」的约束不够显眼

- **现状**：需要一个终端常驻 `./start-*.sh`，另一个终端跑 `./run-codex.sh exec "..."`。
- **问题**：用户关掉第一个终端或开错终端，会得到「proxy not reachable」类错误，不一定立刻想到是「服务被关掉了」。
- **建议**：
  - Quick start 用**加粗**或小标题写：「第一步：在一个终端里运行 start，并保持该终端打开；第二步：在另一个终端里运行 run-codex」。
  - `run-codex.sh` 在 proxy 不可达时，错误信息里补一句：「请确认已在另一个终端运行 ./start-llama-server.sh 或 ./start-vllm.sh 且未关闭。」

### 5. 停止方式分散

- **现状**：停服务可以：在 start 所在终端 Ctrl+C，或任意终端 `./stop-llama-server.sh` / `./stop-vllm.sh`。
- **问题**：新用户不知道「原来可以单独跑一个 stop 脚本」，可能只会关终端或杀进程。
- **建议**：start 脚本在打印「Codex proxy running at...」之后，补一行：「停止服务：本终端 Ctrl+C，或任意终端执行 ./stop-llama-server.sh（或 ./stop-vllm.sh）。」统一入口 `./stop.sh` 后，这句改为「或执行 ./stop.sh」。

### 6. 离线拷盘步骤不够「清单化」

- **现状**：文档写了「整个目录拷走」，并列了 models/、.venv、.codex、llama_bin。
- **问题**：操作员容易漏拷某个目录，到离线环境才发现起不来。
- **建议**：
  - 在 README 的「Copying into an air-gapped workspace」下加一个**清单**（checklist）：  
    「拷盘前请确认目录内包含：□ models/  □ .venv/  □ .codex/  □ llama_bin/  □ codex-proxy 已构建（或拷入后在该环境执行 make proxy）」。
  - 可选：提供 `./scripts/check-portable.sh`，在拷盘前执行，检查上述目录/文件是否存在并打印 OK/MISSING，便于交付前自检。

---

## 二、可落地的改进优先级

| 优先级 | 改进项 | 预期效果 | 状态 |
|--------|--------|----------|------|
| P0 | 统一入口：`./start.sh` 与 `./stop.sh`（自动选 CPU/GPU） | 用户只记两条命令，出错时也只需查 start/stop | ✅ 已完成 |
| P0 | 修正 README Quick start：默认模型写清 CPU=GGUF、GPU=HF，并与当前代码一致 | 减少「我到底用的哪个模型」的困惑 | ✅ 已完成（CPU 与 GPU 默认模型统一为 Qwen3.5-2B） |
| P1 | run-codex 在 proxy 不可达时，提示「请确认已在另一终端运行 ./start-*.sh 且未关闭」 | 减少「服务没开」类困惑 | ✅ 已完成 |
| P1 | start 脚本结尾打印停止方式（Ctrl+C 或 ./stop.sh） | 停止方式更可发现 | ✅ 已完成 |
| P2 | 拷盘清单 + 可选 check-portable.sh | 减少漏拷导致的离线失败 | ✅ 已完成 |
| P2 | 未 bootstrap 时 start 的报错中，增加「无网时请在有网机器 bootstrap 后整目录拷入」 | 离线场景更清晰 | ✅ 已完成 |

---

## 三、不建议做的（保持简单）

- **不**在默认路径里自动检测 GPU 并切换后端（除非做成可选 opt-in）：避免「同一命令在不同机器上行为不同」的隐性复杂度。
- **不**把 bootstrap 和 start 合并成一条命令：bootstrap 需要网络、可能很慢，且通常只做一次；分开更符合「准备一次，多次启动」的心智。
- **不**隐藏 codex-proxy：保留为实现细节，文档中可只提「本地会启动一个代理，无需配置」，不要求用户记住端口或改配置。

---

## 四、README 与文档可立刻修的一处

- ✅ **Quick start 第 1 步**：已修正。CPU 和 GPU 默认统一为 Qwen3.5-2B（CPU：bartowski/Qwen_Qwen3.5-2B-GGUF，GPU：Qwen/Qwen3.5-2B）。README 中已明确说明。

## 五、已实现的额外改进（v0.4.x）

- **CPU 上下文大小自动检测**：根据可用内存自动设置（2048–32768），无需用户手动配置 `LLAMA_CTX_SIZE`。
- **GPU 上下文自动检测**：移除硬编码 `--max-model-len 102400`，由 vLLM 根据 GPU 显存自动决定。
- **新增调参环境变量**：`VLLM_MAX_MODEL_LEN`、`VLLM_GPU_MEM_UTIL`、`VLLM_MAX_NUM_SEQS`，覆盖自动检测值。
- **GGUF 模型的 vLLM 支持**：bootstrap 自动下载 tokenizer，`start-vllm.sh` 自动传入 `--tokenizer`。
- **测试覆盖增强**：`run_tests.sh` / `run_tests_vllm.sh` 新增 proxy Responses API（非流式+流式）和 Chat Completions 流式穿透测试。

以上改进清单中所有 P0-P2 项均已完成。
