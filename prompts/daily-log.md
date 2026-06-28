---
description: Write a daily log entry in knowledge-base format
argument-hint: "<topic> [more topics...]"
---
Write a new daily log file named `日志$(date +%Y.%-m.%-d).md` in `subrepos/personal-base/knowledge/`.

Use the format from existing logs:
- Date heading: # YYYY.M.D
- Bullet points per topic
- Questions I encountered
- Things I learned
- Cross-references to other notes

Content topics: $@
