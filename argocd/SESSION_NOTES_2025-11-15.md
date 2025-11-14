## ArgoCD setup session — 2025-11-15

Summary
-------
This document records the actions performed while installing and configuring ArgoCD on the TechTorque k3s deployment, validating ingress and TLS, and registering the prod/dev "app-of-apps" applications.

Status (end of session)
-----------------------
- ArgoCD installed in namespace `argocd`.
- Traefik IngressRoute configured and TLS certificate (Let's Encrypt) successfully issued.
- ArgoCD reachable at: `https://argocd.techtorque.randitha.net` (DNS resolves to 4.187.182.202).
- Initial admin password retrieved and CLI installed. Logged in via browser and CLI.
- Prod and Dev "app-of-apps" resources applied. Dev apps registered; prod apps registered. Per-app syncs performed; previously OutOfSync apps were synced and are Healthy.

What we did (ordered)
---------------------
1. Pulled latest `k8s-config` repo and inspected `argocd` manifests.

2. Installed ArgoCD

   - Ran the provided installer script:

```bash
sudo ./install-argocd.sh
```

   - Installer created CRDs, RBAC, ServiceAccounts, Deployments, Services and other ArgoCD resources in `argocd` namespace.

3. Configured Ingress + TLS

   - Made the `configure-ingress.sh` executable and ran it to patch ArgoCD to run in insecure (HTTP) mode behind Traefik and to apply Traefik IngressRoute objects and cert-manager Certificate:

```bash
sudo bash ./configure-ingress.sh
```

   - The script created Traefik middleware/IngressRoute and a `certificate.cert-manager.io/argocd-techtorque-tls` object.
   - Waited for cert-manager to issue a Let's Encrypt certificate (script reports successful issuance).

4. DNS / Access verification

   - Verified DNS resolution locally (example):

```bash
dig +short argocd.techtorque.randitha.net
nslookup argocd.techtorque.randitha.net
```

   - Verified TLS certificate (example):

```bash
echo | openssl s_client -connect argocd.techtorque.randitha.net:443 -servername argocd.techtorque.randitha.net 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

5. Retrieve initial admin password & install CLI

   - Retrieved the initial admin password (note: `kubectl` required `sudo` on this host because k3s kubeconfig is owned by root):

```bash
sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

   - Installed ArgoCD CLI and verified version:

```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd
argocd version --client
```

   - Logged in using the CLI (example):

```bash
argocd login argocd.techtorque.randitha.net --username admin --password '<PASSWORD>'
```

6. Applied prod app-of-apps and dev app-of-apps

   - Applied the production app-of-apps (required sudo for kubectl):

```bash
sudo kubectl apply -f environments/prod/app-of-apps-prod.yaml
```

   - Applied the development app-of-apps:

```bash
sudo kubectl apply -f environments/dev/app-of-apps-dev.yaml
```

7. Inspect, dry-run and sync apps with ArgoCD CLI

   - List applications:

```bash
argocd app list
```

   - Inspect diffs for `techtorque-services-prod` (example):

```bash
argocd app diff techtorque-services-prod --grpc-web
```

   - Dry-run sync (safe preview):

```bash
argocd app sync techtorque-services-prod --dry-run
```

   - Performed actual sync and waited for completion:

```bash
argocd app sync techtorque-services-prod
argocd app wait techtorque-services-prod --timeout 120
```

   - Used `--prune` when appropriate to remove stray resources managed by Git:

```bash
argocd app sync techtorque-services-prod --prune
```

Results and notable observations
--------------------------------
- SharedResourceWarning: When both dev and prod app-of-apps targeted `default` namespace resources, ArgoCD emitted SharedResourceWarning messages for resources like `Service/frontend-service` and several `ConfigMap` objects. This was expected because the repository assignments for dev and prod overlapped resource names/namespaces.
- The diffs showed environment-specific differences (notably replica counts and argocd tracking-id labels), e.g., dev had replicas: 2 vs prod replicas: 1 in some Deployments.
- After inspecting diffs and running a dry-run, we executed a sync + prune for `techtorque-services-prod`. The sync succeeded and the application reached `Synced` and `Healthy`.

Quick remediation guidance (follow-ups)
------------------------------------
- Consider separating environments by namespace (dev/prod) in the manifests to avoid SharedResourceWarning.
- Alternatively, extract genuinely shared resources (Services, shared ConfigMaps) into a `platform` or `shared` app that is the single owner.
- Rotate the ArgoCD admin password and configure RBAC / SSO (Dex / OIDC) for team access.
- Add repo credentials if you plan to add private repositories.
- Enable notifications (argocd-notifications) and connect to Slack/Email for alerts.

Files referenced during this session
-----------------------------------
- `argocd/install-argocd.sh` (installer run)
- `argocd/configure-ingress.sh` (ingress + cert setup)
- `argocd/argocd-ingress.yaml` and `argocd/environments/*` (app-of-apps manifests)
- `k8s/config/letsencrypt-issuer.yaml` (cert-manager issuer configuration)

Commands history snippet (most-significant commands run)
-----------------------------------------------------
See the steps above; main commands were:

```bash
sudo ./install-argocd.sh
sudo bash ./configure-ingress.sh
sudo kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd /usr/local/bin/argocd
argocd login argocd.techtorque.randitha.net --username admin --password '<PASSWORD>'
sudo kubectl apply -f environments/prod/app-of-apps-prod.yaml
sudo kubectl apply -f environments/dev/app-of-apps-dev.yaml
argocd app diff techtorque-services-prod --grpc-web
argocd app sync techtorque-services-prod --dry-run
argocd app sync techtorque-services-prod --prune
```

Notes & security
----------------
- The admin password printed from the cluster should be treated as a secret; rotate it after first-use.
- The `~/.kube/config` or `/etc/rancher/k3s/k3s.yaml` contains cluster credentials. Do not commit these to source control.

If you want, I can:
- Create a short `argocd/README_NEXT_STEPS.md` with the runbook and recommended quick fixes, or
- Propose a small patch to separate dev/prod namespaces in `k8s/services` and `argocd/environments` to avoid shared-resource conflicts.

— session recorded by the automation flow on 2025-11-15
