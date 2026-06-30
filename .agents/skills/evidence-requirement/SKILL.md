---
name: evidence-requirement
description: Require explicit evidence for every generated claim, decision, code change, or explanation. Use when verifying claims, reviewing generated code, making architectural decisions, debugging, or explaining how something works. The agent must cite specific sources (file:line, URL, test output, log line, documentation reference) rather than making unsupported assertions.
---

# Evidence Requirement

Every output the agent produces must trace back to evidence the user can independently verify.

## What counts as evidence

- **Source code**: `file.py:42` — the exact file and line
- **Test result**: `uv run pytest tests/test_foo.py::test_bar -v` shows `1 passed`
- **Error/log output**: the exact log line or stack trace
- **Documentation**: URL or file path + section heading
- **API spec**: OpenAPI path + method
- **Command output**: the exact stdout/stderr from a run command
- **Benchmark/profiling**: numbers from a profiler or benchmark run
- **Config**: `config.yaml:15` pointing to the exact key

## What does NOT count

- "The documentation says so" without a URL or path
- "The code handles it" without a line number
- "Testing shows it works" without the exact test command + output

## Application patterns

### Code generation
When creating or changing code, cite the evidence chain:
```
The handler in `src/app.py:88` calls `validate_token()`.
Changing the auth check at `src/auth.py:31` to accept the new role.
Test: `uv run pytest tests/test_auth.py::test_admin_access -v` → `1 passed`
```

### Debugging
Show the evidence trail end to end:
```
# 1. Error evidence
curl output → `500 Internal Server Error`
Log line `app.log:2026-06-28 ERROR: ...`

# 2. Root cause (found at src/db.py:112)
The `cursor.fetchone()` returns `None` when no rows match.

# 3. Fix (at src/db.py:113-115)
Added fallback default.

# 4. Fix evidence
Re-ran curl → `200 OK` with expected response
```

### Factual claims
Cite the source inline:
```
vLLM uses PagedAttention (paper: https://arxiv.org/abs/2309.06180).
The `max_num_seqs` default is 256 (vllm/config.py:512).
```

### Architectural decisions
Show the trade-off evidence:
```
Decision: use Redis instead of in-memory cache.
Evidence: benchmarks/redis-vs-memory.md:12 shows 2ms vs 1ms p99 latency —
negligible difference. Redis enables horizontal scaling (docs/arch/cache.md:8).
```

### Explaining existing code
Point to the exact location:
```
The retry logic is in `src/retry.py:24-42`. It uses exponential backoff
with jitter, configured in `config.yaml:15` as `max_retries: 3`.
```

## Enforcement

Before finishing any response, check every assertion made. For each one:
- Does it have a specific source (file:line, URL, test run)?
- If not, either add the evidence or remove the assertion.
