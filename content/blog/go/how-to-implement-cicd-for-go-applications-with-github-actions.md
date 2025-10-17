---
title: "How to Implement CI/CD for Go Applications with GitHub Actions"
description: "Complete guide to implementing CI/CD pipelines for Go applications using GitHub Actions. Learn automated testing, building, Docker deployment, caching strategies, and production best practices."
date: 2025-10-17T11:00:00+07:00
tags: ["Go", "CI/CD", "GitHub Actions", "DevOps", "Automation", "Testing", "Deployment"]
draft: false
author: "Wiku Karno"
keywords: ["Go CI/CD", "GitHub Actions Go", "Golang automated testing", "Go deployment pipeline", "CI/CD best practices", "GitHub Actions workflow", "automated Go builds", "Go testing automation"]
url: /2025/10/how-to-implement-cicd-for-go-applications-with-github-actions.html
faq:
  - question: "What is CI/CD and why is it important for Go applications?"
    answer: "CI/CD (Continuous Integration/Continuous Deployment) automates testing, building, and deploying your code. For Go applications, CI/CD runs tests on every commit, builds binaries automatically, deploys to production without manual steps, and catches bugs before they reach users. This speeds up development, improves code quality, enables faster releases, and reduces manual errors. GitHub Actions provides free CI/CD for public repositories and generous limits for private ones."
  - question: "How do I set up GitHub Actions for a Go project?"
    answer: "Create a .github/workflows directory in your repository root, add a YAML file defining your workflow (e.g., ci.yml), specify trigger events (push, pull_request), configure Go version with actions/setup-go, and define steps for testing, building, and deploying. GitHub Actions automatically runs workflows when triggered. No server setup needed - GitHub provides runners that execute your workflows in the cloud."
  - question: "What are the best practices for Go CI/CD pipelines?"
    answer: "Cache Go modules to speed up builds, run tests in parallel when possible, use matrix builds to test multiple Go versions, separate build and test jobs for clarity, implement linting and formatting checks, build for multiple platforms when needed, cache Docker layers for container builds, use secrets for sensitive data, and fail fast on critical errors. Keep workflows simple and focused on specific tasks."
  - question: "How do I run tests automatically with GitHub Actions?"
    answer: "Use go test command in your workflow with proper flags: go test -v -race -coverprofile=coverage.out ./... runs tests with race detection and coverage. Add go test -short for quick checks on pull requests and full tests on main branch. Upload coverage reports to Codecov or Coveralls for tracking. Run tests on multiple OS (Linux, macOS, Windows) with matrix strategy to ensure cross-platform compatibility."
  - question: "How do I deploy Go applications with GitHub Actions?"
    answer: "Build your Go binary with go build, optionally create Docker image with docker build, push image to registry (Docker Hub, GitHub Container Registry, AWS ECR), and deploy using SSH to VPS, kubectl for Kubernetes, or cloud provider CLI. Use environment-specific secrets for credentials, deploy only from main/production branches, and implement health checks to verify deployment success before marking workflow complete."
  - question: "How do I cache dependencies in GitHub Actions for Go?"
    answer: "Use actions/cache action with Go module cache path (~/.cache/go-build and ~/go/pkg/mod on Linux). Create cache key based on go.sum file hash so cache invalidates when dependencies change. Caching reduces workflow time from minutes to seconds by skipping module downloads. For Docker builds, use buildx with cache-from and cache-to options to cache Docker layers between builds."
---

Manual deployments are error-prone and time-consuming. You make a change, run tests locally, build the binary, SSH into servers, copy files, restart services, and hope nothing breaks. Multiply this by ten deployments per day and you've wasted hours on repetitive tasks that should be automated.

This guide demonstrates how to implement CI/CD (Continuous Integration/Continuous Deployment) for Go applications using GitHub Actions. You'll learn to create automated workflows that test code on every push, build optimized binaries for multiple platforms, deploy Docker containers automatically, cache dependencies for faster builds, and apply production-ready practices that catch bugs before users do.

## Understanding CI/CD for Go Applications

Continuous Integration automatically tests and builds your code whenever changes occur. Developers push code to Git, GitHub Actions runs tests, and the team gets immediate feedback about code quality. CI catches integration issues early when they're cheap to fix.

Continuous Deployment takes CI further by automatically deploying tested code to production. When tests pass, GitHub Actions builds the application, creates Docker images, and deploys to servers - all without manual intervention. CD enables multiple deployments per day safely.

Go applications benefit particularly from CI/CD because Go's fast compilation and simple dependency management make automated builds quick. A typical Go CI/CD pipeline completes in 2-5 minutes, providing rapid feedback. Go's static binaries simplify deployment - no runtime dependencies to manage.

GitHub Actions provides the automation platform. It runs workflows triggered by Git events (push, pull request, release), executes jobs on GitHub-hosted or self-hosted runners, supports matrix builds for testing multiple configurations, and integrates with GitHub's ecosystem. For public repositories, GitHub Actions is free with unlimited minutes.

## Setting Up Your First GitHub Actions Workflow

GitHub Actions workflows live in `.github/workflows/` directory as YAML files. Each file defines a workflow with jobs and steps that run when triggered.

Create the basic directory structure:

```bash
mkdir -p .github/workflows
```

Create a simple workflow file `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'

    - name: Run tests
      run: go test -v ./...
```

This workflow triggers on pushes to main/develop branches and pull requests to main. It checks out code, sets up Go 1.21, and runs all tests.

Commit and push this file:

```bash
git add .github/workflows/ci.yml
git commit -m "Add CI workflow"
git push
```

GitHub Actions automatically detects the workflow and runs it. View results in the "Actions" tab of your GitHub repository.

## Running Tests with Coverage

Expand the test job to include coverage reporting and race detection.

```yaml
name: Test

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'
        cache: true

    - name: Run tests with coverage
      run: |
        go test -v -race -coverprofile=coverage.out -covermode=atomic ./...

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.out
        flags: unittests
        name: codecov-umbrella
```

The `-race` flag detects data races, `-coverprofile` generates coverage data, and `codecov-action` uploads results to Codecov for tracking over time.

## Testing Multiple Go Versions with Matrix Strategy

Test against multiple Go versions to ensure compatibility.

```yaml
name: Test Matrix

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    strategy:
      matrix:
        go-version: ['1.20', '1.21', '1.22']
        os: [ubuntu-latest, macos-latest, windows-latest]

    runs-on: ${{ matrix.os }}

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go ${{ matrix.go-version }}
      uses: actions/setup-go@v5
      with:
        go-version: ${{ matrix.go-version }}
        cache: true

    - name: Run tests
      run: go test -v ./...

    - name: Run tests with race detector (Linux/macOS only)
      if: runner.os != 'Windows'
      run: go test -race -v ./...
```

This creates 9 jobs (3 Go versions × 3 operating systems), running in parallel. Matrix builds verify your code works across different environments.

## Implementing Linting and Code Quality Checks

Add automated linting to enforce code standards.

```yaml
name: Lint

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  golangci-lint:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'
        cache: true

    - name: Run golangci-lint
      uses: golangci/golangci-lint-action@v3
      with:
        version: latest
        args: --timeout=5m

  gofmt:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'

    - name: Check formatting
      run: |
        if [ "$(gofmt -s -l . | wc -l)" -gt 0 ]; then
          echo "The following files are not formatted:"
          gofmt -s -l .
          exit 1
        fi

  govet:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'
        cache: true

    - name: Run go vet
      run: go vet ./...
```

golangci-lint runs multiple linters in parallel, gofmt ensures consistent formatting, and go vet catches common mistakes.

## Building Binaries for Multiple Platforms

Create optimized binaries for different operating systems and architectures.

```yaml
name: Build

on:
  push:
    branches: [ main ]
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        goos: [linux, darwin, windows]
        goarch: [amd64, arm64]
        exclude:
          - goos: windows
            goarch: arm64

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'
        cache: true

    - name: Build binary
      env:
        GOOS: ${{ matrix.goos }}
        GOARCH: ${{ matrix.goarch }}
        CGO_ENABLED: 0
      run: |
        OUTPUT_NAME=myapp-${{ matrix.goos }}-${{ matrix.goarch }}
        if [ "${{ matrix.goos }}" == "windows" ]; then
          OUTPUT_NAME="${OUTPUT_NAME}.exe"
        fi
        go build -ldflags="-s -w" -o build/${OUTPUT_NAME} ./cmd/myapp

    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: binaries
        path: build/
```

This builds for Linux, macOS, and Windows on both x64 and ARM64 architectures (excluding Windows ARM64). Binaries are uploaded as artifacts for download or use in later jobs.

## Caching Go Modules for Faster Builds

Module caching dramatically reduces workflow time.

```yaml
name: CI with Cache

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'
        cache: true  # Automatically caches Go modules

    - name: Download dependencies
      run: go mod download

    - name: Run tests
      run: go test -v ./...
```

The `cache: true` option in `actions/setup-go` automatically caches `~/go/pkg/mod` and `~/.cache/go-build`. Cache keys use `go.sum` hash, so cache invalidates when dependencies change.

First build: 2-3 minutes. Cached builds: 30-60 seconds.

## Building and Pushing Docker Images

Automate Docker image creation and registry pushing.

```yaml
name: Docker Build and Push

on:
  push:
    branches: [ main ]
    tags:
      - 'v*'

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  docker:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
    - uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to Container Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
        tags: |
          type=ref,event=branch
          type=ref,event=pr
          type=semver,pattern={{version}}
          type=semver,pattern={{major}}.{{minor}}
          type=sha,prefix={{branch}}-

    - name: Build and push
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        labels: ${{ steps.meta.outputs.labels }}
        cache-from: type=gha
        cache-to: type=gha,mode=max
```

This builds Docker images using buildx (supports multi-platform), pushes to GitHub Container Registry (ghcr.io), tags images based on branch/tag/commit, and caches layers between builds using GitHub Actions cache.

## Deploying to Production with SSH

Automate deployment to VPS or dedicated servers via SSH.

```yaml
name: Deploy

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
    - name: Deploy to server
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.SERVER_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          cd /opt/myapp
          git pull origin main
          go build -o myapp ./cmd/myapp
          sudo systemctl restart myapp
```

Add secrets in repository settings (Settings → Secrets and variables → Actions):
- `SERVER_HOST`: Your server IP or domain
- `SERVER_USER`: SSH username
- `SSH_PRIVATE_KEY`: Private SSH key for authentication

## Deploying Docker Containers

Deploy Docker images to production servers.

```yaml
name: Deploy Docker

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
    - name: Deploy to server
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.SERVER_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          cd /opt/myapp
          docker pull ghcr.io/${{ github.repository }}:main
          docker-compose down
          docker-compose up -d
          docker image prune -f
```

This pulls the latest Docker image, restarts containers using Docker Compose, and cleans up old images.

## Deploying to Kubernetes

Automate Kubernetes deployments with kubectl.

```yaml
name: Deploy to Kubernetes

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
    - uses: actions/checkout@v4

    - name: Configure kubectl
      uses: azure/k8s-set-context@v3
      with:
        method: kubeconfig
        kubeconfig: ${{ secrets.KUBE_CONFIG }}

    - name: Deploy to cluster
      run: |
        kubectl set image deployment/myapp \
          myapp=ghcr.io/${{ github.repository }}:${{ github.sha }}
        kubectl rollout status deployment/myapp
```

Store kubeconfig in `KUBE_CONFIG` secret. This updates deployment with new image and waits for rollout to complete.

## Complete Production Workflow

Combine all concepts into a production-ready workflow.

```yaml
name: Production CI/CD

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  release:
    types: [published]

env:
  GO_VERSION: '1.21'
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: ${{ env.GO_VERSION }}
        cache: true

    - name: Run tests
      run: go test -v -race -coverprofile=coverage.out ./...

    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.out

  lint:
    name: Lint
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: ${{ env.GO_VERSION }}
        cache: true

    - name: Run golangci-lint
      uses: golangci/golangci-lint-action@v3
      with:
        version: latest

  build:
    name: Build
    needs: [test, lint]
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: ${{ env.GO_VERSION }}
        cache: true

    - name: Build binary
      run: |
        CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
        go build -ldflags="-s -w" -o myapp ./cmd/myapp

    - name: Upload binary
      uses: actions/upload-artifact@v3
      with:
        name: myapp-binary
        path: myapp

  docker:
    name: Docker Build and Push
    needs: [test, lint]
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'
    permissions:
      contents: read
      packages: write

    steps:
    - uses: actions/checkout@v4

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v3

    - name: Log in to Registry
      uses: docker/login-action@v3
      with:
        registry: ${{ env.REGISTRY }}
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Extract metadata
      id: meta
      uses: docker/metadata-action@v5
      with:
        images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}

    - name: Build and push
      uses: docker/build-push-action@v5
      with:
        context: .
        push: true
        tags: ${{ steps.meta.outputs.tags }}
        cache-from: type=gha
        cache-to: type=gha,mode=max

  deploy-staging:
    name: Deploy to Staging
    needs: [docker]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    environment: staging

    steps:
    - name: Deploy via SSH
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.STAGING_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          cd /opt/myapp
          docker-compose pull
          docker-compose up -d

  deploy-production:
    name: Deploy to Production
    needs: [docker]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production

    steps:
    - name: Deploy via SSH
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.PRODUCTION_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          cd /opt/myapp
          docker-compose pull
          docker-compose up -d

    - name: Health check
      run: |
        sleep 10
        curl -f https://myapp.com/health || exit 1
```

This workflow:
1. Runs tests and linting in parallel
2. Builds binary and Docker image after tests pass
3. Deploys to staging from develop branch
4. Deploys to production from main branch
5. Verifies deployment with health check

## Using GitHub Environments for Deployment Protection

GitHub Environments add protection rules and secrets per environment.

Create environments in repository settings (Settings → Environments):

**Staging Environment:**
- No protection rules
- Secrets: `STAGING_HOST`

**Production Environment:**
- Required reviewers: Add team members who must approve deployments
- Wait timer: Optional delay before deployment
- Secrets: `PRODUCTION_HOST`

Update workflow to use environments:

```yaml
deploy-production:
  name: Deploy to Production
  needs: [docker]
  runs-on: ubuntu-latest
  environment:
    name: production
    url: https://myapp.com

  steps:
    # Deployment steps
```

Deployments to production now require manual approval, adding safety to your pipeline.

## Implementing Rollback Strategy

Add rollback capability for failed deployments.

```yaml
name: Rollback

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to'
        required: true
        type: string

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: production

    steps:
    - name: Rollback via SSH
      uses: appleboy/ssh-action@v1.0.0
      with:
        host: ${{ secrets.SERVER_HOST }}
        username: ${{ secrets.SERVER_USER }}
        key: ${{ secrets.SSH_PRIVATE_KEY }}
        script: |
          cd /opt/myapp
          docker pull ghcr.io/${{ github.repository }}:${{ inputs.version }}
          docker-compose down
          docker-compose up -d
```

Trigger manually from Actions tab by selecting workflow and providing version tag.

## Monitoring Workflow Performance

Track workflow execution times and identify bottlenecks.

Add timing information to jobs:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v4

    - name: Set up Go
      uses: actions/setup-go@v5
      with:
        go-version: '1.21'
        cache: true

    - name: Run tests with timing
      run: |
        START_TIME=$(date +%s)
        go test -v ./...
        END_TIME=$(date +%s)
        echo "Tests took $((END_TIME - START_TIME)) seconds"
```

GitHub Actions automatically tracks total workflow time in the Actions tab. Use this data to optimize slow steps.

## Best Practices for Go CI/CD

Keep workflows fast by caching dependencies, running jobs in parallel, and using matrix builds efficiently. Workflows under 5 minutes provide quick feedback.

Fail fast by running cheap checks (linting, formatting) before expensive ones (tests, builds). Place critical jobs early so failures stop the workflow quickly.

Use meaningful job and step names that clearly describe what's happening. Good names make debugging failed workflows easier.

Separate concerns by splitting workflows into multiple files: `test.yml` for testing, `build.yml` for building, `deploy.yml` for deployment. This makes workflows easier to understand and maintain.

Secure secrets properly by storing them in GitHub Secrets, never committing them to code, and limiting access to production secrets to specific branches or environments.

Document workflows with comments explaining complex steps or non-obvious logic. Future maintainers will thank you.

## Integration with Other Tools

Combine CI/CD with other development tools for complete automation.

Use [database migrations](/2025/10/how-to-perform-database-migrations-in-go-using-golang-migrate.html) in deployment workflows to automatically update schemas.

Integrate [mock testing](/2025/10/how-to-use-mock-testing-in-go-with-testify-and-mockery.html) to ensure complete test coverage in CI.

Deploy [containerized applications](/2025/10/how-to-containerize-and-deploy-go-apps-with-docker.html) built in your workflow.

## Conclusion

CI/CD changes Go application development from manual, error-prone processes to automated, reliable workflows. GitHub Actions provides free, easy-to-configure automation that tests every change, builds optimized binaries, and deploys to production without manual intervention.

The patterns demonstrated here - automated testing with coverage, multi-platform builds, Docker integration, staged deployments, and environment protection - create production-ready pipelines that catch bugs early and deploy confidently. Start with basic testing workflows and gradually add complexity as needs grow.

Remember that CI/CD is an investment that pays dividends quickly. Initial setup takes hours, but saves countless hours preventing bugs and automating repetitive tasks. Every team member benefits from faster feedback, fewer integration issues, and reliable deployments.

Build your CI/CD pipeline incrementally: start with automated tests, add linting, implement building, and finally automate deployment. Each step improves development workflow and code quality, making the next step easier to justify and implement.
