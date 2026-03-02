# Project Charter — Air-Gapped Codex + llama.cpp

**All future development of this project shall follow this charter. It defines why we exist, who we serve, and what we will not become.**

---

## 1. Purpose and problem

### The pain we solve

In **high-security and classified environments**, system operators and DevOps engineers routinely work in **air-gapped** networks. In the strictest sites, **no personal electronic devices** (phones, laptops, USB drives with external data) are allowed in the secure area. Looking up documentation, examples, or runbooks is **difficult or impossible**. When the task is complex—e.g. configuring Kubernetes, deploying enterprise applications, or troubleshooting production issues—**efficiency drops sharply** and errors increase.

This project exists to give those operators a **single, portable, offline-capable AI agent** they can bring into the closed environment (on an approved workspace machine) and use for **deployment, configuration, operations, and fault-finding**—without any cloud, internet, or external API.

### What we deliver

A **self-contained directory** that:

- Runs a **local LLM** via **llama.cpp** (CPU-only inference, no GPU) so it works on typical air-gapped workstations.
- Drives **Codex CLI** (a state-of-the-art coding/ops agent) against that local model, so users get the same agent experience they would with a cloud API, but **fully offline**.
- Can be **prepared once** on a connected machine (bootstrap: build llama.cpp, download GGUF model, generate config) and then **copied as a whole** (e.g. via approved media) into the air-gapped workspace. No network is required on the target side.

**In one sentence:**  
*We provide a portable, offline-first “Codex + local LLM” kit so that sysadmins and DevOps can use a top-tier agent for system operations and troubleshooting inside locked-down, air-gapped, or classified environments.*

---

## 2. Target users

- **System administrators** and **DevOps/SRE** working in:
  - Air-gapped or heavily firewalled networks  
  - Classified or high-security facilities where internet and personal devices are forbidden  
  - Isolated labs, on-prem data centers, or secure rooms where “looking it up” is not an option  

- **Use cases we optimize for:**
  - Deploying and configuring Kubernetes, services, and enterprise applications  
  - Writing and adjusting configs, scripts, and runbooks  
  - Operational troubleshooting and debugging  
  - Following best practices and reducing mistakes when documentation is hard to access  

We do **not** primarily target: general-purpose “run any LLM locally” users, researchers needing the latest models, or environments where cloud APIs are allowed and preferred.

---

## 3. Guiding principles

1. **Portable and offline-first**  
   The artifact is a directory. Once bootstrapped (on a machine with internet), it must run in the air-gapped workspace **without** network access. All config and state stay under that directory (e.g. `.codex`); no dependency on `~/.codex` or global cloud config.

2. **CPU-only inference**  
   Many secure workstations have no GPU. The project uses **llama.cpp** with CPU-only builds so that operators without GPUs can run the agent. No GPU or CUDA dependency.

3. **Codex as the agent interface**  
   We use **Codex CLI** as the agent front-end (tools, exec, planning, sandboxing). Our job is to make Codex work against a **local** model served by llama-server (OpenAI-compatible API), not to replace Codex with a different agent stack.

4. **Single, clear workflow**  
   Bootstrap once → copy folder → start local server → run Codex. Documentation and scripts must keep this path obvious and robust. Avoid optional complexity that doesn’t serve the air-gapped ops use case.

5. **Transparency and auditability**  
   No telemetry or phone-home. All processing is local. The stack (llama.cpp, Codex, model choice) is documented and version-pinned where it matters (see VERSIONS.md) so operators and security reviewers can reason about what runs in the secure zone.

---

## 4. In scope

- **Bootstrap and portability:** One-command setup (e.g. `./bootstrap.sh` or `make deps`) that produces a folder that can be copied and run offline.  
- **Local serving:** llama-server (llama.cpp) serving a chosen model (default: Qwen/Qwen3.5-2B via GGUF for CPU, same model HF for GPU).  
- **Codex integration:** Config and scripts so Codex uses the local llama-server endpoint (OpenAI-compatible API), with state confined to the project (e.g. `CODEX_HOME`).  
- **Documentation:** Clear README (including for non-English speakers where applicable), version baseline (VERSIONS.md), and troubleshooting for the “copy in and run” workflow.  
- **Operational usability:** Model selection (including quantized/GGUF for resource-constrained or CPU-only boxes), port/config overrides, and basic testing (e.g. `make test`) to validate the stack.

---

## 5. Out of scope (we will not)

- **Replace or fork Codex.** We integrate with the official Codex CLI; we do not ship a competing agent.  
- **Become a general “local LLM playground.”** We are not targeting hobbyists who just want to chat with a local model; we stay focused on **ops/DevOps in air-gapped or locked-down environments**.  
- **Require cloud or internet at runtime.** The value proposition is “works fully offline after copy.” Features that assume network access in the secure zone are out of scope unless clearly optional and documented.  
- **Add telemetry, analytics, or external calls** from the kit when run in the air-gapped workspace.  
- **Guarantee support for every model or hardware.** We document a baseline (llama.cpp build, Codex version, default GGUF model) and keep that path tested; exotic setups may require user adaptation.

---

## 6. Success criteria

- An operator in an air-gapped environment can:  
  - Obtain the project (e.g. from approved media or a one-time transfer).  
  - Run a simple bootstrap (or use a pre-bootstrapped copy).  
  - Start the local llama-server (CPU).  
  - Run Codex (e.g. `./run-codex.sh exec "..."`) and get useful help for deployment, config, or troubleshooting—**without any network**.  

- Documentation clearly states: **who it is for**, **what problem it solves**, and **how to get started** in both English and (where provided) Chinese.  

- The project charter (this document) is the reference for “why we build this”; design and PRs should align with it and not drift toward generic local-LLM or cloud-first tooling.

---

*This charter may be updated only with explicit agreement that the change preserves the project’s focus on portable, offline-first, Codex-powered operations in air-gapped and high-security environments.*
