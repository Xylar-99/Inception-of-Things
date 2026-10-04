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
From the repository root, run:

```bash
bash bonus/scripts/setup.sh
```

It creates `iot-bonus`, installs Argo CD `v3.5.3`, and installs GitLab chart `10.4.1`. The chart source is cached under `~/.cache/iot/gitlab-10.4.1`. Its development helpers supply database, cache, and object-storage dependencies; local overrides disable several optional components and enable HTTP ingress through Traefik.

Open these services after setup:

| Service | URL | Username |
| --- | --- | --- |
| GitLab | `http://gitlab.iot.local` | `root` |
| Argo CD | `http://argocd.iot.local` | `admin` |

Passwords are printed at the end of setup. The Argo CD Application uses this internal repository address:

```text
http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/iot/abquaoub-iot.git
```

After GitLab is installed:

1. Log in to `http://gitlab.iot.local` as `root` using the printed password.
2. Create a group named `iot` and a project inside it named `abquaoub-iot`.
3. Push your application's Kubernetes manifests into a `manifests/` directory on the `main` branch.
4. Make the repository public, or configure repository credentials in Argo CD for a private project.

Argo CD automatically deploys the manifests into the `dev` namespace. Include an ingress for `app.iot.local` in those manifests to access the application at `http://app.iot.local`.
