# Git Workflow

This document explains the git workflow for the Notification Platform, including submodule management, branching conventions, and the commit/merge process.

---

## Repository Structure

The project uses a **monorepo with git submodules**:

```
notification-platform/              ← Root repository
├── services/
│   ├── admin-dashboard/            ← Submodule (independent git repo)
│   ├── user-service/               ← Submodule (independent git repo)
│   ├── notification-service/       ← Submodule (independent git repo)
│   ├── messaging-service/          ← Submodule (independent git repo)
│   └── template-service/           ← Submodule (independent git repo)
├── docs/                           ← Part of root repo
├── scripts/                        ← Part of root repo
└── README.md                       ← Part of root repo
```

- **Root repo** tracks documentation, scripts, and submodule pointers.
- **Each service** is its own git repo with its own history, branches, and tags.
- The root repo's `.gitmodules` file maps each service to its remote URL.

---

## Cloning

```bash
# Clone everything (root + all services)
git clone --recurse-submodules <root-repo-url>

# If already cloned without submodules
git submodule update --init --recursive
```

---

## Branch Naming

Use conventional prefixes:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feat/` | New feature | `feat/notification-orchestration` |
| `fix/` | Bug fix | `fix/jwt-expiry-check` |
| `test/` | Test additions/fixes | `test/user-device-edge-cases` |
| `docs/` | Documentation changes | `docs/api-contracts-update` |
| `chore/` | Maintenance, deps, config | `chore/update-dependencies` |
| `refactor/` | Code restructuring | `refactor/extract-client-trait` |

---

## Feature Branch Workflow (Service Repo)

When making changes to a single service:

```bash
# 1. Enter the service directory
cd services/notification-service

# 2. Start from main
git checkout main
git pull

# 3. Create feature branch
git checkout -b feat/my-feature

# 4. Make changes, commit
git add -A
git commit -m "feat(notification): add idempotency protection"

# 5. Run tests
php artisan test

# 6. Push feature branch
git push -u origin feat/my-feature

# 7. Merge to main (after review)
git checkout main
git merge feat/my-feature

# 8. Run tests again on main
php artisan test

# 9. Push main
git push

# 10. Clean up
git branch -d feat/my-feature
git push origin --delete feat/my-feature
```

---

## Updating Submodule Pointers

After pushing changes in a service repo, update the root repo's pointer:

```bash
# 1. Go to root repo
cd ~/lampp/htdocs/notification-platform

# 2. The submodule directory now points to the new commit
git add services/notification-service

# 3. Commit the pointer update
git commit -m "chore(submodules): bump notification-service"

# 4. Push root repo
git push
```

### Bumping Multiple Services

```bash
git add services/user-service services/template-service
git commit -m "chore(submodules): bump user-service and template-service"
git push
```

---

## Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]
```

### Types

| Type | When to use |
|------|-------------|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `test` | Adding or updating tests |
| `docs` | Documentation changes |
| `chore` | Maintenance (deps, config, scripts) |
| `refactor` | Code restructuring without behavior change |
| `style` | Formatting, whitespace (no logic change) |

### Scope

Use the service name or component:

- `feat(notification): ...`
- `fix(user): ...`
- `docs(testing): ...`
- `chore(submodules): ...`
- `chore(scripts): ...`

### Examples

```
feat(notification): add idempotency protection for duplicate requests
fix(template): handle inactive template rendering with 409 response
test(messaging): add push and whatsapp provider edge case tests
docs(architecture): add notification orchestration sequence diagram
chore(submodules): bump notification-service
```

---

## Multi-Service Changes

When a feature spans multiple services (e.g., notification orchestration touches notification-service, user-service, template-service):

1. Make changes in each service repo on feature branches.
2. Test each service independently.
3. Merge each service to main and push.
4. Update all submodule pointers in the root repo in a single commit.

```bash
cd ~/lampp/htdocs/notification-platform
git add services/notification-service services/user-service services/template-service
git commit -m "chore(submodules): bump services for notification orchestration"
git push
```

---

## Root Repo Changes

Documentation, scripts, and configuration that live in the root repo follow the same branch workflow:

```bash
cd ~/lampp/htdocs/notification-platform
git checkout -b docs/update-architecture
# Make changes to docs/
git add docs/
git commit -m "docs(architecture): update orchestration flow diagrams"
git checkout main
git merge docs/update-architecture
git push
```

---

## Common Pitfalls

### Detached HEAD in submodules

After `git submodule update`, submodules may be in detached HEAD state. Always check out a branch before making changes:

```bash
cd services/user-service
git checkout main
```

### Forgetting to push the submodule

If you commit in a service repo but forget to push, other developers pulling the root repo will see a broken submodule pointer. Always push the service repo before updating the root pointer.

### Stale submodule pointers

If someone else updated a service, pull the root repo and update submodules:

```bash
git pull
git submodule update --recursive
```
