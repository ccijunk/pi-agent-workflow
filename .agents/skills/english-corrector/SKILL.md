---
name: english-corrector
description: Correct the user's English in conversation and save language learning notes to vocabulary. Use when the user's English has errors or when they ask you to correct them.
---

# English Corrector Skill

## What It Does

1. **Filter** what the user is saying — identify grammar mistakes, wrong word choices, awkward phrasing
2. **Correct** the user's English in your response (show the fixed version)
3. **Save** language learning knowledge to the vocabulary system in `secretary/state.json`

## When to Activate

- The user's English has obvious errors (grammar, word choice, spelling, sentence structure)
- The user explicitly asks "correct my English" or "fix my grammar"
- The user says something that sounds off or unnatural in English

## How to Respond

### Format

```
💬 You said: "<original>"
✅ Correct: "<corrected version>"
📝 Note: <brief explanation of the correction>
```

Then continue with your normal response to the user's actual question.

### What to Correct

- **Grammar**: tense errors, subject-verb agreement, articles (a/an/the), plural/singular
- **Word choice**: wrong word for the context, false friends, awkward collocations
- **Spelling**: obvious typos and misspellings
- **Sentence structure**: run-on sentences, fragments, unnatural word order

### What NOT to Correct

- Technical terms that are clearly intentional (kubectl, vcjob, ETCD, etc.)
- Acronyms and abbreviations the user uses deliberately
- Casual/informal tone — don't make them sound like a textbook
- Minor stylistic preferences — only fix things that are clearly wrong

## Save to Vocabulary

After correcting, if the correction reveals a **language pattern** worth remembering (not just a typo), save it:

```bash
cd /home/laeq/code/harness/pi-agent-workflow/subrepos/personal-base && uv run python3 << 'PYEOF'
import json
from datetime import datetime, timezone

state_path = 'secretary/state.json'
with open(state_path) as f:
    state = json.load(f)

state.setdefault('vocabulary', []).append({
    'word': '<word or grammar pattern>',
    'definition': '<what it means or the correct usage>',
    'context': '<the original sentence vs corrected version>',
    'added': datetime.now(timezone.utc).isoformat(),
    'pillar': 'english',
    'tags': ['<grammar|spelling|word-choice|phrase>']
})

with open(state_path, 'w') as f:
    json.dump(state, f, indent=2, ensure_ascii=False)
PYEOF
```

### When to Save vs Not Save

**Save when:**
- It's a grammar rule the user is clearly struggling with (e.g., mixing up past tense)
- It's a new word or phrase
- It's a word choice pattern (e.g., using "saying" when they mean "meaning")
- It's something the user might repeat

**Don't save when:**
- It's a one-off typo ("teh" instead of "the")
- The user was clearly typing fast and knows the correct form
- It's a minor article issue ("a" vs "an" — save only if it's a pattern)

## Examples

### Example 1: Grammar Error

User: "evicts 1 pod that is runing"

Your response:
```
💬 You said: "evicts 1 pod that is runing"
✅ Correct: "evicts 1 Pod that is running"
📝 Note: "running" (double n) — present continuous of "run". Also "Pod" is capitalized as a Kubernetes resource kind.
```

Then answer the question about eviction.

### Example 2: Word Choice

User: "what is tevict"

Your response:
```
💬 You said: "what is tevict"
✅ Correct: "what is 'evict'"
📝 Note: "tevict" isn't a word — likely a typo for "evict". When asking about a word's meaning, use "what does X mean" or "what is X".
```

### Example 3: Sentence Structure

User: "i want you to have a skill that crroect my english in the conversation"

Your response:
```
💬 You said: "i want you to have a skill that crroect my english in the conversation"
✅ Correct: "I want you to have a skill that corrects my English in the conversation"
📝 Note: "corrects" (third person singular + s) and "English" is always capitalized. "crroect" → "correct" (spelling).
```

## When to Skip the Correction Block

Skip the `💬 / ✅` block if:
- The user's English is already correct
- The error is so minor it's not worth calling out
- The user is clearly in a hurry and just wants the answer
- The conversation is technical and adding corrections would be distracting

In these cases, you can still save vocab silently without showing the correction block.

## Pillar Assignment

English-related vocabulary entries use `pillar: 'english'` to distinguish them from technical AI/K8s vocabulary which uses `pillar: 'ai'`.
