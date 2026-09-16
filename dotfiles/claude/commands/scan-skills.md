---
description: Scan the current repo for technologies, then search the skills.sh catalog for relevant skills
argument-hint: [extra-keywords...]
allowed-tools: ['Read', 'Glob', 'Grep', 'Bash']
model: sonnet
---

# Scan Repo for Relevant Skills

Inventory the technologies used in this codebase, then query the open agent skills catalog (`npx skills find`) for matching skills the user could install.

Additional keywords from the user: **$ARGUMENTS** (treat as extra search terms to include alongside detected tech)

## Phase 1 — Detect Technologies

Use parallel tool calls. Pull from these signals (skip any that don't exist):

### Language / package manifests

- `package.json` → JS/TS deps, frameworks (React, Next, Vue, etc.)
- `pyproject.toml` / `requirements*.txt` / `Pipfile` / `poetry.lock` → Python
- `go.mod` → Go modules
- `Cargo.toml` → Rust crates
- `Gemfile` / `*.gemspec` → Ruby
- `pom.xml` / `build.gradle*` → JVM
- `composer.json` → PHP
- `*.csproj` / `*.fsproj` → .NET
- `mix.exs` → Elixir
- `pubspec.yaml` → Dart/Flutter

### Infrastructure / DevOps signals

- `Dockerfile*`, `docker-compose*.y*ml` → Docker
- `*.tf`, `*.tfvars` → Terraform
- `*.bicep`, ARM templates → Azure
- `serverless.yml`, `samconfig.toml` → serverless
- `Taskfile*.y*ml` → go-task
- `Makefile` → make
- `lefthook.yaml`, `.pre-commit-config.yaml`, `.husky/` → git hooks
- `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/` → CI
- `kustomization.y*ml`, `helmfile.y*ml`, `Chart.yaml` → K8s tooling
- `flux-system/`, `clusters/*/`, `apps/` w/ HelmRelease → Flux
- `argocd/`, `Application` CRDs → ArgoCD
- `Tiltfile`, `skaffold.y*ml`, `devspace.y*ml` → dev orchestration
- `ansible.cfg`, `playbook*.y*ml`, `roles/` → Ansible
- `Vagrantfile` → Vagrant
- `cloudformation/`, `cdk.json` → AWS CDK/CFN

### Kubernetes ecosystem (grep namespace names + manifests)

Look for these strings across yaml files: `cilium`, `calico`, `flannel`, `traefik`, `nginx-ingress`, `cert-manager`, `external-secrets`, `external-dns`, `authentik`, `keycloak`, `prometheus`, `grafana`, `loki`, `tempo`, `mimir`, `alloy`, `opentelemetry`/`otel`, `fluent-bit`, `fluentd`, `graylog`, `opensearch`, `elasticsearch`, `minio`, `rook-ceph`, `longhorn`, `kubevirt`, `metallb`, `kube-vip`.

### Repo metadata

- `catalyst_repo.yaml` / `README.md` — explicit tech_stack hints
- `CLAUDE.md` / `AGENTS.md` — project context

Output a deduplicated list grouped by category (Languages, Frameworks, Infra, K8s ecosystem, CI/CD, Tools). Cap at ~25 buckets; merge synonyms (e.g. `react` + `next.js` stay separate but both go under Frameworks).

## Phase 2 — Query the Skills Catalog

For each detected technology bucket (plus any `$ARGUMENTS` keywords), run:

```bash
npx -y skills find <keyword> 2>&1 | head -20
```

Batch these in **parallel** (multiple Bash calls in one message) — do not serialize. Sensible defaults:

- One query per major tech (don't fan out to 30+ — pick the top ~10-15 most central)
- Skip generic terms like `yaml`, `bash`, `json` unless the user explicitly asked
- If a search returns "No skills found", drop it silently from the report

## Phase 3 — Present Findings

Output format:

```
## Detected Stack

- **Languages:** ...
- **Frameworks:** ...
- **Infrastructure:** ...
- **K8s ecosystem:** ...
- **CI/CD & tooling:** ...

## Recommended Skills

### <Technology>
- `owner/repo@skill-name` (N installs) — one-line gist
  Install: `npx skills add owner/repo@skill-name`

### <Technology>
- ...
```

Rules for the recommendations:

- **Filter quality**: prefer skills with >100 installs, or from trusted orgs (`hashicorp`, `grafana`, `microsoft`, `github`, `vercel-labs`, `fluxcd`, `dotnet`, `google`). Drop low-install spammy-looking ones unless they're the only match.
- **Pick the top 1–3 per technology** — do not dump every result.
- **Group skills**, not raw search dumps. If `wshobson/agents` has 5 relevant skills, list them under one heading.
- **No duplicates**: if the same skill matches multiple keywords, list it once under the most relevant heading.
- **Skip if nothing useful**: if a tech has only generic/low-quality matches, omit it entirely.

End with:

> To install: `npx skills add <owner/repo@skill>` (add `-g -y` to install globally without prompts).
> Browse all skills at https://skills.sh

## Notes

- This command is read-only — never install skills automatically. The user picks.
- If `npx` isn't available, fall back to telling the user how to install Node/npx and link https://skills.sh.
- Don't ask follow-up questions; just produce the report. If `$ARGUMENTS` is empty, work entirely from detection.
