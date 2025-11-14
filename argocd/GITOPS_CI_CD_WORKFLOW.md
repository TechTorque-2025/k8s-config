# GitOps CI/CD Workflow with ArgoCD

## Overview

This document describes the updated CI/CD workflow for the TechTorque-2025 microservices architecture using ArgoCD and GitOps principles.

## Previous Architecture (Old Method)

- Each microservice repo had `build.yaml` and `deploy.yaml` workflows
- Build workflow: Built Docker images and pushed to GHCR
- Deploy workflow: Directly applied K8s manifests using `kubectl apply`
- Used `kubeconfig` secrets to access the cluster
- Manual image tag updates in k8s-config repo

**Problems:**
- Direct kubectl access to cluster (security risk)
- No audit trail of what was deployed
- Manual updates to manifests
- Tight coupling between CI and cluster

## New Architecture (ArgoCD + GitOps)

### Core Principles

1. **Git as Single Source of Truth**: All desired cluster state lives in `k8s-config` repo
2. **ArgoCD Monitors Git**: ArgoCD watches branches (`main` for prod, `dev` for dev) and auto-syncs
3. **CI Updates Git**: Microservice CI builds images and updates manifests in k8s-config
4. **No Direct Cluster Access**: CI never touches the cluster directly

### Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  Developer pushes to microservice repo (dev or main branch) │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions: Build Workflow                             │
│  1. Build application (Maven/npm)                           │
│  2. Build Docker image                                      │
│  3. Tag with branch-SHA (e.g., dev-abc1234 or main-xyz5678)│
│  4. Push to ghcr.io/techtorque-2025/<service>              │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions: Update Manifest Workflow                   │
│  1. Checkout k8s-config repo (matching branch)              │
│  2. Update image tag in k8s/services/<service>.yaml         │
│  3. Commit and push to k8s-config/<branch>                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  ArgoCD detects Git change                                  │
│  - Dev apps watch k8s-config/dev branch                     │
│  - Prod apps watch k8s-config/main branch                   │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│  ArgoCD auto-syncs to cluster                               │
│  - Applies new manifest to correct namespace (dev/default)  │
│  - Kubernetes pulls new image and rolls out                 │
│  - No manual intervention needed                            │
└─────────────────────────────────────────────────────────────┘
```

## Branch Strategy

### Development Flow

```
Microservice Repo (dev branch)
  ↓ push/PR merge
Build → Image: ghcr.io/techtorque-2025/<service>:dev-<sha>
  ↓ update
k8s-config (dev branch) → k8s/services/<service>-deployment.yaml
  ↓ ArgoCD watches
Cluster (dev namespace)
```

### Production Flow

```
Microservice Repo (main branch)
  ↓ PR merge from dev
Build → Image: ghcr.io/techtorque-2025/<service>:main-<sha>
  ↓ update
k8s-config (main branch) → k8s/services/<service>-deployment.yaml
  ↓ ArgoCD watches
Cluster (default namespace)
```

## Required Changes

### 1. Update Microservice Build Workflows

**Current Issues:**
- Images tagged with `:latest` and short SHA only
- No branch-specific tags
- Deploy workflow uses kubectl directly (bypasses ArgoCD)

**Required Changes:**

#### build.yaml Updates

```yaml
# Add branch-aware tagging
- name: Docker meta
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ghcr.io/techtorque-2025/<service_name>
    tags: |
      # Branch name + SHA (e.g., dev-abc1234 or main-xyz5678)
      type=raw,value={{branch}}-{{sha}},enable=true
      # Latest tag only for default branch
      type=raw,value=latest,enable={{is_default_branch}}
```

#### Replace deploy.yaml with update-manifest.yaml

```yaml
name: Update K8s Manifest

on:
  workflow_run:
    workflows: ["Build and Package Service"]
    types: [completed]
    branches: ['main', 'dev']

jobs:
  update-manifest:
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    runs-on: ubuntu-latest
    
    steps:
      - name: Get branch and SHA
        id: info
        run: |
          echo "branch=${{ github.event.workflow_run.head_branch }}" >> $GITHUB_OUTPUT
          echo "sha=$(echo ${{ github.event.workflow_run.head_sha }} | cut -c1-7)" >> $GITHUB_OUTPUT
      
      - name: Checkout k8s-config (matching branch)
        uses: actions/checkout@v4
        with:
          repository: 'TechTorque-2025/k8s-config'
          token: ${{ secrets.REPO_ACCESS_TOKEN }}
          ref: ${{ steps.info.outputs.branch }}  # Checkout same branch!
          path: 'k8s-config'
      
      - name: Install yq
        run: |
          sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
          sudo chmod +x /usr/bin/yq
      
      - name: Update image tag
        run: |
          cd k8s-config
          NEW_IMAGE="ghcr.io/techtorque-2025/<service>:${{ steps.info.outputs.branch }}-${{ steps.info.outputs.sha }}"
          # Use --arg to pass the new_image into yq so it doesn't depend on env variable export
          yq -i --arg new_image "${NEW_IMAGE}" '(select(.kind == "Deployment") | .spec.template.spec.containers[0].image) = $new_image' \
            k8s/services/<service>-deployment.yaml
      
      - name: Commit and push
        run: |
          cd k8s-config
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add k8s/services/<service>-deployment.yaml
          git commit -m "chore(<service>): update image to ${{ steps.info.outputs.branch }}-${{ steps.info.outputs.sha }}"
          git push origin ${{ steps.info.outputs.branch }}
```

### 2. Required Secrets

Each microservice repo needs:

- `REPO_ACCESS_TOKEN`: Personal Access Token (PAT) or GitHub App token with:
  - `repo` scope (to push to k8s-config)
  - `packages:write` (already have via GITHUB_TOKEN)

**How to create:**
1. Go to GitHub Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Create token with access to `TechTorque-2025/k8s-config` repo
3. Add as secret to each microservice repo: Settings → Secrets → Actions → New repository secret

### 3. Update k8s-config Manifests

**Remove hardcoded tags:**
Current manifests have:
```yaml
image: ghcr.io/techtorque-2025/<service>:latest
```

Should be updated by CI to:
```yaml
image: ghcr.io/techtorque-2025/<service>:dev-abc1234  # or main-xyz5678
```

**Add imagePullPolicy:**
```yaml
containers:
- name: <service>-container
  image: ghcr.io/techtorque-2025/<service>:dev-abc1234
  imagePullPolicy: Always  # Important for tag updates
```

### 4. ArgoCD Configuration

ArgoCD is already configured correctly:
- Dev apps watch `k8s-config/dev` branch → deploy to `dev` namespace
- Prod apps watch `k8s-config/main` branch → deploy to `default` namespace
- Auto-sync enabled

**Verify sync policy:**
```bash
argocd app get techtorque-services-dev
argocd app get techtorque-services-prod
```

Should show:
```
Sync Policy:        Automated (Prune)
```

## Testing the Workflow

### Test Dev Deployment

1. Make a change in a microservice `dev` branch
2. Push or merge PR to `dev`
3. Watch GitHub Actions:
   - Build workflow runs → pushes image `ghcr.io/.../service:dev-<sha>`
   - Update manifest workflow runs → updates `k8s-config/dev`
4. Watch ArgoCD:
   ```bash
   argocd app get techtorque-services-dev
   argocd app sync techtorque-services-dev  # if not auto
   ```
5. Verify pods:
   ```bash
   kubectl get pods -n dev
   kubectl describe pod <pod-name> -n dev  # check image
   ```

### Test Prod Deployment

1. Merge dev → main in microservice repo (via PR)
2. Build workflow runs → pushes image `ghcr.io/.../service:main-<sha>`
3. Update manifest workflow runs → updates `k8s-config/main`
4. ArgoCD syncs to `default` namespace
5. Verify:
   ```bash
   argocd app get techtorque-services-prod
   kubectl get pods -n default
   ```

## Rollback Strategy

### Using ArgoCD

```bash
# View history
argocd app history techtorque-services-prod

# Rollback to previous revision
argocd app rollback techtorque-services-prod <revision-id>
```

### Using Git

```bash
# In k8s-config repo
git revert <commit-sha>
git push origin main  # or dev

# ArgoCD will auto-sync the revert
```

## Migration Checklist

- [ ] Create REPO_ACCESS_TOKEN and add to all microservice repos
- [ ] Update build.yaml in all microservice repos (branch-aware tags)
- [ ] Replace deploy.yaml with update-manifest.yaml in all repos
- [ ] Add imagePullPolicy: Always to all k8s/services/*.yaml
- [ ] Test workflow with one service (e.g., frontend or timelogging)
- [ ] Verify ArgoCD picks up changes
- [ ] Roll out to remaining services
- [ ] Remove KUBE_CONFIG_DATA secret (no longer needed)
- [ ] Update documentation and runbooks

## Services to Update

- [ ] Admin_Service
- [ ] Agent_Bot
- [ ] API_Gateway
- [ ] Appointment_Service
- [ ] Authentication
- [ ] Frontend_Web
- [ ] Notification_Service
- [ ] Payment_Service
- [ ] Project_Service
- [ ] Time_Logging_Service
- [ ] Vehicle_Service

## Benefits of New Architecture

1. **Security**: No kubeconfig in CI, cluster credentials stay with ArgoCD
2. **Audit Trail**: Every deployment is a Git commit
3. **Rollback**: Simple git revert or ArgoCD history
4. **Separation of Concerns**: CI builds, ArgoCD deploys
5. **Multi-Environment**: Same workflow for dev/prod, just different branches
6. **Declarative**: Cluster state matches Git, always
7. **Review**: Can review manifest changes via PR before ArgoCD applies

## Troubleshooting

### Image not updating

- Check ArgoCD app status: `argocd app get <app>`
- Force refresh: `argocd app get <app> --refresh`
- Check image pull policy in manifest
- Verify image exists: `docker pull ghcr.io/techtorque-2025/<service>:<tag>`

### Manifest update failed

- Check REPO_ACCESS_TOKEN has repo scope
- Verify k8s-config branch exists (dev/main)
- Check GitHub Actions logs for git push errors

### ArgoCD not syncing

- Check sync policy: `argocd app get <app>`
- Manual sync: `argocd app sync <app>`
- Check for sync errors/warnings in ArgoCD UI

## Next Steps

1. Read this document
2. Review example workflows in `argocd/examples/`
3. Create PAT token
4. Update one service as pilot (recommend: Time_Logging_Service or Frontend_Web)
5. Test end-to-end
6. Roll out to remaining services
7. Document any service-specific quirks

---

**Document created:** 2025-11-15  
**Last updated:** 2025-11-15  
**Status:** Ready for implementation
