---
description: Debug a failing CI workflow
argument-hint: "<workflow-name>"
---
Read the failing CI workflow log and the workflow definition file.
Focus on:
1. The test selection step — which tests were selected and why?
2. The actual failure — is it a test issue, environment issue, or code issue?
3. The PR changes that triggered it — check git diff against main

Workflow file: .github/workflows/$1.yaml
