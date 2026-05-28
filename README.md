# pipeline-lab

A fully containerized local DevSecOps pipeline — a GitHub Actions self-hosted runner triggering Terraform plan/apply against MiniStack (AWS-compatible emulator), with no host pollution and a Makefile as the sole operator interface.

## Prerequisites

- **Docker** (running and accessible without `sudo`)
- **GitHub repo** named `pipeline-lab`
- **GitHub Runner Registration Token** (from repo Settings → Actions → Runners → New self-hosted runner)
- **GitHub PAT** (fine-grained, repo-scoped, with Administration: Read and Write for runner deregistration)

## Quickstart

```bash
# 1. Copy the env template and fill in real values
cp .env.template .env
# Edit .env — set GITHUB_RUNNER_TOKEN, GITHUB_PAT, GITHUB_OWNER

# 2. Start all containers
make up

# 3. Push to main to trigger the pipeline
git push
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make up` | Start all containers (MiniStack + runner + UI) |
| `make down` | Stop containers, preserve state |
| `make destroy` | Deregister runner, remove containers + volumes + state |
| `make status` | Show running container status |
| `make logs` | Tail all container logs |
| `make ui` | Open MiniStack dashboard in browser |

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                        Docker Host                           │
│                                                              │
│  ┌─────────────────┐    ┌──────────────────────┐            │
│  │   MiniStack      │    │   GitHub Runner       │            │
│  │   (AWS compat)   │◀───│   (self-hosted)       │            │
│  │   :4566          │    │   Runs Terraform      │            │
│  └────────┬─────────┘    └──────────┬───────────┘            │
│           │                         │                        │
│           │   pipeline-net (bridge)  │                        │
│           │◀────────────────────────▶│                        │
│                                                              │
│  ┌─────────────────┐    ┌──────────────────────┐             │
│  │ Host :4566      │    │  StackPort UI        │             │
│  │ MiniStack API   │    │  :8080 (dashboard)   │             │
│  └─────────────────┘    └──────────────────────┘             │
└──────────────────────────────────────────────────────────────┘
        │                              ▲
        │  Push to main                │  Polls for jobs
        ▼                              │
   ┌──────────┐              ┌──────────────────┐
   │ GitHub   │              │ GitHub Actions    │
   │ Repo     │──────────────│ Service           │
   └──────────┘              └──────────────────┘
```

The GitHub Actions workflow (`.github/workflows/terraform-plan.yml`) triggers on pushes to `main`. The self-hosted runner executes Terraform inside the Docker network, reaching MiniStack via the `ministack` service hostname. MiniStack emulates S3, DynamoDB, IAM, STS, KMS, CloudTrail, EC2, CloudWatch Logs, Secrets Manager, and more.

## Phase I Scope

- Credentials are hardcoded in Terraform provider config (test keys only, safe for local dev)
- Terraform resources: VPC, private subnets, security group, S3 + DynamoDB VPC endpoints, KMS key, IAM role with permission boundary, S3 audit bucket with versioning + public access block, CloudTrail trail
- Vault integration for secrets management is planned for Phase II
- State is stored locally in Terraform default (no remote backend yet)

## GitHub Actions Workflow

See [terraform-plan.yml](.github/workflows/terraform-plan.yml) for the pipeline definition.