Create a draft pull request for all current local changes. Handles branch management, commit (with pre-commit hooks), rebase, push, PR creation, and a code review summary.

## Usage

`/create-pr`

No arguments required.

## Steps

### 1. Assess current state

```bash
git branch --show-current
git status --short
git diff --stat HEAD
```

If the working tree is **completely clean** (no changes, nothing staged, nothing untracked that belongs in the commit): Inform the user and continue to the next steps.

### 2. Branch management

**Case A — currently on `main`:**

- Read the full diff to understand the nature of changes.
- Generate a branch name using the pattern: `<type>/<short-slug>` matching Conventional Commits types.
  - Examples: `feat/add-pr-command`, `fix/talos-bootstrap-endpoint`, `chore/update-providers`, `docs/readme-cleanup`
- Present the suggested name and ask the user to confirm or provide an alternative.
- Run: `git checkout -b <branch-name>`

**Case B — already on a feature branch:**

- Read the full diff to understand the nature of changes.
- Evaluate whether the existing branch name semantically fits the changes (AI judgment).
- If it fits: proceed to Step 3.
- If it does NOT fit: suggest a better name and ask the user to confirm:
  - Rename: `git branch -m <new-name>`
  - Keep existing: proceed with current name

### 3. Stage, review, and commit

Stage all changes:

```bash
git add -A
git diff --cached --stat
```

Show the staged file summary to the user.

Generate a commit message following **Conventional Commits** format, consistent with project history:

```
<type>(<scope>): <short description in imperative mood>

- <key change 1>
- <key change 2>
```

Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`, `test`
Scope: the component or directory being changed (e.g. `claude-code`, `terraform`, `k8s`, `packer`, `ci`)

Present the generated commit message to the user for confirmation before committing. The user must approve or edit the message.

Run the commit (this triggers pre-commit hooks and git-crypt transparent encryption):

```bash
git commit -m "<confirmed message>"
```

**Pre-commit auto-fix loop handling:**

Some hooks (trailing-whitespace, end-of-file-fixer, terraform fmt) auto-fix files and abort the commit. If the commit is aborted due to hook modifications:

1. Re-stage automatically: `git add -A`
2. Retry the commit once with the same message.
3. If it fails a second time: **stop**. Group and display errors by hook type using the same format as `/validate-all`. Do NOT retry further — present the errors and wait for the user to fix them.

### 4. Rebase onto remote main

```bash
git fetch origin main
git rebase origin/main
```

If rebase reports conflicts:

- List all conflicting files.
- Instruct the user to resolve each conflict manually, then run `git rebase --continue`.
- **Stop** — do not proceed to push until the user resolves conflicts and re-runs the command.

If rebase is a no-op (branch is already up to date): proceed.

### 5. Push branch

> ⚠ This step requires explicit user confirmation before executing.

Show the exact command that will run:

```bash
git push --set-upstream origin <branch-name>
```

Wait for the user to confirm. Only push after explicit approval.

### 6. Create draft PR via MCP

Parse the GitHub repository owner and name:

```bash
git remote get-url origin
```

Extract `owner` and `repo` from the URL (handles both HTTPS and SSH formats).

Call `mcp__github__create_pull_request` with:

- `title`: the commit message subject line (first line only)
- `body`: structured PR description (template below)
- `head`: current branch name
- `base`: `main`
- `draft`: `true`

**PR body template** (fill from diff context):

```markdown
## What changed

- <bullet: key change 1>
- <bullet: key change 2>

## Why

<one or two sentences inferred from the commit message and diff>

## How to test

<relevant verification steps — pick what applies>

- `task kubernetes:plan` — Terraform changes
- `kubectl get nodes -o wide` — K8s manifest changes
- `task packer:validate` — Packer template changes
- `/validate-all` — general pre-commit check
- `/k8s-status` — cluster state check

---

_Draft PR — created by `/create-pr`. Mark as ready for review when complete._
```

### 7. Review (terminal only)

Launch an Agent subagent that:

1. Fetches the PR diff using `mcp__github__pull_request_read` with the PR number returned from step 6.
2. Reviews the diff against these criteria:
   - **Code quality**: correctness, naming conventions, consistency with existing patterns
   - **Security**: no plaintext secrets, tokens, passwords, or credentials
   - **Conventional commit compliance**: commit message type/scope match the actual changes
   - **Pre-commit alignment**: changes are consistent with what the hooks enforce

3. Prints a structured review summary in the terminal:

```
## PR Review Summary
PR: <url>
Branch: <branch-name> → main

### Code Quality
<findings or "✅ No issues">

### Security
<findings or "✅ No issues">

### Commit & Branch
<findings or "✅ Conventional commit format looks correct">

### Overall
✅ Looks good — ready to mark as ready for review
⚠ Minor issues — consider addressing before marking ready
❌ Issues found — address before marking ready for review
```

**No comment is posted to GitHub.**

### 8. Done

Print:

```
✅ Draft PR created: <PR URL>

Review the summary above. When you're satisfied, mark the PR as ready for review on GitHub.
```

## Notes

- `git push` is in the project's confirmation-required list — always wait for explicit approval.
- The command works on any modified, new, or deleted files. It stages everything with `git add -A`.
- If the user is on `main` and declines the suggested branch name, ask for their preferred name before creating the branch.
- The PR is always created as a draft — never as a ready-for-review PR without explicit user action.
