# Vocab Saver Skill

When the user asks "what does X mean?" or "meaning of X" or "save X as vocabulary" or "add X to my vocabulary", do this:

## Steps

### 1. Explain the word concisely
Give a 1-2 sentence plain-English definition with a concrete example from the current context (K8s, Volcano, Karmada, etc.).

### 2. Save to vocabulary
Run this Python script to append the word to `secretary/state.json`:

```bash
cd /home/laeq/code/harness/pi-agent-workflow/subrepos/personal-base && uv run python3 << 'PYEOF'
import json
from datetime import datetime, timezone

state_path = 'secretary/state.json'
with open(state_path) as f:
    state = json.load(f)

state.setdefault('vocabulary', []).append({
    'word': '<WORD>',
    'definition': '<1-2 sentence definition>',
    'context': '<how this came up in our conversation>',
    'added': datetime.now(timezone.utc).isoformat(),
    'pillar': 'ai',
    'tags': ['<relevant tags>']
})

with open(state_path, 'w') as f:
    json.dump(state, f, indent=2, ensure_ascii=False)

print('saved')
PYEOF
```

### 3. Confirm
Tell the user it's saved and that they can view it at http://localhost:8192/progress.

## When to trigger
- User says: "what does X mean", "meaning of X", "define X"
- User says: "save X to vocabulary", "add X as vocabulary", "store X as a vocabulary"
- Any conversation where a technical term is explained and the user seems to be learning it

## Vocabulary format
- `word`: the term itself
- `definition`: plain English, 1-2 sentences max
- `context`: one sentence tying it to the current conversation
- `pillar`: always "ai" for technical terms in this context
- `tags`: relevant tags like kubernetes, volcano, karmada, scheduling, etc.
