# Global Pi Context

## About me
- I maintain several Python repos and a Markdown knowledge base
- I use `uv` for Python package management, `nvm` for Node.js
- I work on AI infrastructure, LLM inference, and agent systems

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
