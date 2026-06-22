---
name: oncall-dev
description: Common development tasks and run commands for the oncall-agent-python project (FastAPI, LangChain, Milvus, MCP tools)
---

# Oncall Agent Dev Tasks

## Project structure
- app/main.py — FastAPI entrypoint
- app/services/ — RAG, AIOps, vector services
- app/agent/ — MCP client, AIOps planner/executor/replanner
- app/core/ — Milvus client, LLM factory
- app/api/ — REST endpoints (chat, aiops, upload, health)
- mcp_servers/ — MCP tool servers (cls_server, monitor_server)
- static/ — Web frontend

## Run all services locally
```bash
# Terminal 1: Milvus
docker compose -f vector-database.yml up -d

# Terminal 2: MCP servers
python mcp_servers/cls_server.py &
python mcp_servers/monitor_server.py &

# Terminal 3: FastAPI with hot-reload
uvicorn app.main:app --host 0.0.0.0 --port 9900 --reload
```

## Run tests
```bash
uv run pytest tests/ -v
```

## Format code
```bash
uv run black app/ tests/
uv run ruff check --fix app/ tests/
```

## Type check
```bash
uv run mypy app/
```

## Add a new MCP tool
1. Create `mcp_servers/<name>_server.py` following the pattern in `mcp_servers/monitor_server.py`
2. Register it in `app/agent/mcp_client.py`
3. Add a tool wrapper in `app/tools/` if needed
