# CLAUDE.md

## Commit Guidelines

**Never** include references to Claude, AI models, agents, or LLM in commit messages.

- Do not use "Co-Authored-By" with any AI-related identifiers
- Do not mention models like Claude, GPT, Gemini, etc. in commit messages
- Do not reference agents, skills, or plugins in commit messages
- Write commit messages as if a human developer wrote them
- Focus on **what** changed and **why**, not on **how** it was generated

## Example

**Good:**
```
feat: add retry logic to API service with 5 attempts and 15s delay
```

**Bad:**
```
feat: add retry logic (Claude implementation)
feat: implemented by AI agent
Co-Authored-By: Claude <noreply@anthropic.com>
```
