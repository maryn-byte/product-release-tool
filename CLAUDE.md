## Starting a New Project from This Repo
If this repo is being used as a template for a brand-new app, do the following before writing any feature code:
1. **`pyproject.toml`** — update `name` and `description`.
2. **`app.py`** — replace the `SEED_DATA` array and any hardcoded team/resource names with content relevant to the new app.
3. **`templates/index.html`** — replace `DEFAULT_RELEASE_NAMES`, engineer/designer/user option arrays, and the page title with content relevant to the new app.
4. **`windows_deploy.bat`** — update the three PROJECT CONFIGURATION lines (`AWS_PROFILE`, `REPO`, `REGION`).
5. **`Dockerfile`** — update `APP_BASE_PATH` if the app will live at a different URL path.
6. **`.claude/skills/deploy/SKILL.md`** — update the description if the app name changes.
7. All other config (hooks, launch scripts, git workflow) is fully portable and requires no changes.

## Preview
- After making any code changes, always invoke the preview skill to ensure the dev server is running and a Chrome tab is viewing the app.

## Git Workflow
- Automatically commit changes after completing a logical unit of work.
- Automatically push commits to the remote origin on the current branch.
- Use conventional commit messages with an extra signifier that this code was modified or produced by Claude.
- Stay on the `main` branch where possible. You are the only developer of this app.