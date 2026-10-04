# Inception of Things

A Kubernetes learning project using Vagrant, K3s, k3d, Argo CD, and a local GitLab installation.

## Project structure

| Directory | Purpose |
| --- | --- |
| `p1/` | Two Ubuntu VMs: a K3s server and an agent. |
| `p2/` | One K3s VM serving three Nginx applications through ingress. |
| `p3/` | A Docker-based k3d cluster with Argo CD syncing an external GitHub repository. |
| `bonus/` | A k3d cluster with Argo CD and GitLab, using external development dependencies from the GitLab chart helpers. |

Vagrantfiles define `bento/ubuntu-24.04` VMs with one CPU and 1024 MB RAM each, using the `libvirt` provider. Scripts are in each directory's `scripts/`; Kubernetes manifests and Helm values are in `confs/`.

## Requirements

- For parts 1 and 2: Vagrant, the `vagrant-libvirt` plugin, working libvirt/KVM, and support for Vagrant shared folders at `/vagrant`.
- For part 3 and the bonus: an Ubuntu/Debian-style Linux host with `sudo`, Docker access, and internet connectivity. The installers download the Linux **amd64** kubectl binary.
- Part 3 installs Docker, kubectl, k3d, Git, and supporting packages when needed. The bonus also installs Helm and OpenSSL.
- If Docker is newly installed, log out and back in to activate Docker group membership before running setup again.
- Host port 80 must be free for k3d. Part 3 and the bonus cannot both bind that port simultaneously.
- Run parts 1 and 2 separately: both use `192.168.56.110` for their server VM.
- Allocate enough host resources for GitLab and its dependencies; this repository does not define a tested minimum for the bonus.

Setup scripts install software, modify `/etc/hosts`, and switch the Kubernetes context. Both k3d setup scripts expect a new cluster; creation fails if their cluster already exists.

## Part 1: K3s server and agent

From the repository root:

```bash
cd p1
vagrant up --provider=libvirt
vagrant ssh abquaoubS -c 'kubectl get nodes -o wide'
```

The server is `abquaoubS` at `192.168.56.110`; the agent is `abquaoubSW` at `192.168.56.111`. The server writes its join token to `/vagrant/k3s-token`, and the agent waits for this file before joining. Both machines must see the same shared folder. Treat the generated token as a secret and do not commit it.

Run Kubernetes inspection commands on the server. The agent's `k=kubectl` alias does not provide API credentials by itself.

## Part 2: applications and ingress

```bash
cd p2
vagrant up --provider=libvirt
vagrant ssh abquaoubS -c 'kubectl get deployments,pods,services,ingress'
curl -H 'Host: app1.com' http://192.168.56.110
curl -H 'Host: app2.com' http://192.168.56.110
curl -H 'Host: other.example' http://192.168.56.110
```

Expected routing:

| Request host | Application | Replicas |
| --- | --- | --- |
| `app1.com` | App 1 | 1 |
| `app2.com` | App 2 | 3 |
| Other hosts / direct IP | App 3 | 1 |

Each application uses a ConfigMap for its HTML page and a Service on port 80. The ingress includes a hostless route and a default backend for App 3. Allow time for Nginx pods and the ingress controller to become ready after provisioning.

To use a browser, map `app1.com` and `app2.com` to `192.168.56.110` in your host's `/etc/hosts`.

## Part 3: GitOps with Argo CD

```bash
bash p3/scripts/setup.sh
```

The script creates `iot-p3`, exposes HTTP on host port 80, creates `dev` and `argocd`, installs Argo CD version `v3.5.3`, and enables HTTP behind Traefik.

Argo CD application `playground` follows branch `main`, directory `manifests`, in:

```text
https://github.com/Xylar-99/younajja-iot-p3.git
```

Automated sync enables pruning and self-healing. The external repository must provide a Service named `playground`, pods labeled `app=playground`, and routing for `app.iot.local` for the setup's checks and advertised application URL to work. Those manifests are not included here.

Open `http://argocd.iot.local` with username `admin` and the password printed by the script. The advertised application URL is `http://app.iot.local`.

Useful inspection commands:

```bash
kubectl get applications -n argocd
kubectl describe application playground -n argocd
kubectl get pods,services,ingress -n dev
```

The script expects a new cluster; rerunning it with `iot-p3` already present fails at cluster creation.

## Bonus: GitLab-backed GitOps

Dependency versions are supplied directly in setup: Valkey chart `0.12.0`, CloudNativePG chart `0.29.0`, PostgreSQL `17`, and Garage `2.2.0`.
The intended entry point is:

```bash
bash bonus/scripts/setup.sh
```

It creates `iot-bonus`, installs Argo CD `v3.5.3`, and installs GitLab chart `10.4.1`. The chart source is cached under `~/.cache/iot/gitlab-10.4.1`. Its development helpers supply database, cache, and object-storage dependencies; local overrides disable several optional components and enable HTTP ingress through Traefik.

Advertised interfaces:

| Service | URL | Username |
| --- | --- | --- |
| GitLab | `http://gitlab.iot.local` | `root` |
| Argo CD | `http://argocd.iot.local` | `admin` |

Passwords are printed at the end of setup. The Argo CD Application uses this internal repository address:

```text
http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/iot/abquaoub-iot.git
```

The setup does not create the `iot` group, the `abquaoub-iot` project, or its Git contents. After GitLab is available, create that repository and push a `main` branch containing the application manifests under `manifests/`. Make it readable by Argo CD: a private repository requires credentials, which the current setup does not configure. An ingress for `app.iot.local` must come from those application manifests if that URL is desired.

## Review findings

The initial review left scripts and configuration unchanged. A subsequent requested fix replaced undefined bonus dependency variables with literal versions. See [REPORT.md](REPORT.md) for findings by part. The project has a coherent structure, but cannot be declared fully working from static checks alone.

1. **Bonus dependency variables were fixed.** Setup now supplies literal versions to the dependency helper. Full deployment still needs verification.
2. **Bonus Git repository provisioning is manual by design.** Create the agreed GitLab project and push the application manifests after GitLab is installed; configure credentials if the project is private.
3. **Several waits have no timeout.** Part 1 waits indefinitely for the token file, part 2 for Kubernetes API access, and part 3 for the `playground` Service. A missing prerequisite or failed sync can leave setup running indefinitely.
4. **Part 1 depends on shared-folder behavior.** Verify that the libvirt shared-folder implementation exposes the server-generated token to the worker. There is no alternative token transport in the scripts.
5. **VM networking needs runtime verification.** The VMs have a management interface plus a private interface, but K3s installation does not explicitly select a node IP or Flannel interface. Check `kubectl get nodes -o wide` and server-agent communication on the actual provider.
6. **Provisioning completion is not application readiness.** Part 2 applies manifests without waiting for deployments or ingress readiness. Part 3 initially waits only for the Argo CD server deployment, rather than all Argo CD components.
7. **Some dependencies are unpinned.** K3s, k3d, kubectl, and Nginx images are selected through latest/default versions, while Argo CD and the GitLab chart are pinned. Reproducibility and version compatibility need verification during deployment.
8. **Part 1 and part 2 installer pipelines lack `pipefail`.** A failed `curl` can be hidden by the exit status of the downstream shell. Their dependency installation also assumes `curl` is already present in the VM image.
9. **Local credentials are exposed intentionally.** K3s kubeconfig is installed with mode `644`, join tokens are written into shared folders, and setup prints administrator passwords. These settings are intended for a local learning environment.

## Validation performed

- Bash syntax checks passed for all seven shell scripts.
- Ruby syntax checks passed for both Vagrantfiles.
- `vagrant validate` passed in both `p1/` and `p2/`.
- All nine YAML files parsed successfully (15 YAML documents total).
- Deployment selectors, Service selectors, and local ingress backend references were inspected.

These checks do not validate Kubernetes schemas, Helm rendering, external repository contents, download availability, or actual cluster behavior. No provisioning, installation, cluster deletion, or application deployment was performed during this review. No assignment specification was provided, so exact evaluation compliance was not assessed.
