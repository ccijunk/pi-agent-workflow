# Global Pi Context

## About me
- I maintain several Python repos and a Markdown knowledge base
- I use `uv` for Python package management, `nvm` for Node.js
- I work on AI infrastructure, LLM inference, and agent systems

## Handling any repo
- **REPO_GUIDE.md** — read this first when you encounter a repo you don't recognize
- It tells you how to discover, clone, understand, and work with any repo
- AGENTS.md below lists only the most frequently-used repos for quick reference

## Project conventions

### daily-record (Markdown knowledge base)
- Each .md file covers one topic area
- Subdirs for multi-file topics (agent/, virtual-machine/, leetcode/)
- Daily logs named 日志YYYY.M.D.md
- Images stored alongside notes

### ai-workflow / flowctl (Python workflow engine)
- Source: src/flowctl/
- Tests: tests/ — run with `uv run pytest tests/ -v`
- Node-graph workflow engine with executors
- YAML workflow definitions in .flows/workflows/

### oncall-agent-python (RAG + AIOps agent)
- FastAPI + LangChain + LangGraph + Milvus
- RAG pipeline: upload → chunk → embed → Milvus → retrieve
- AIOps: Plan-Execute-Replan pattern
- MCP tool integration (CLS logs, monitoring)
- Run: `uvicorn app.main:app --host 0.0.0.0 --port 9900`

### vllm-ascend (Ascend NPU plugin for vLLM)
- Python extension for Ascend hardware
- CI: GitHub Actions in .github/workflows/
- PR titles must have prefix: [Feature], [BugFix], [CI], [Test], [Doc]
- Tests need Ascend NPU hardware (not locally runnable)

### personal-base (English learning & content curation)
- Repo: https://github.com/ccijunk/personal-base.git
- Goal: Learn English via real-world web content (articles, podcasts, code repos)
- Three pillars: AI+Agent+K8s+Code (40%), Investing (40%), Company/Career (20%)
- Rules live in RULES.md — ALWAYS read this first before curating
- **Curator** fetches & filters content: `uv run python -m curator.main all`
- **Secretary** tracks progress & adjusts plans: `uv run python -m secretary status`
- **Website** learning dashboard: `uv run python -m website.main` → http://localhost:8192
- Workflow: `secretary plan` → read → `secretary log` → check dashboard
- Sources: `curator/feeds.yaml` (verified working RSS feeds)
- Tracking data: `secretary/state.json`
- When asked about English learning or content curation, consult RULES.md
