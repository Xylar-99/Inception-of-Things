# 📖 Subject Explained — What You Need To Do

This file explains every part of the project in simple words. Read this before you start coding.

---

## Overview

The project has **3 mandatory parts** + **1 bonus**. You must do them **in order**.

| Part | Name | Tools Used | Folder |
|------|------|-----------|--------|
| 1 | K3s and Vagrant | Vagrant, VirtualBox, K3s | `p1/` |
| 2 | K3s and three simple applications | Vagrant, K3s, Ingress | `p2/` |
| 3 | K3d and Argo CD | Docker, K3d, Argo CD, GitHub | `p3/` |
| Bonus | GitLab | Helm, GitLab, Argo CD | `bonus/` |

---

## Part 1: K3s and Vagrant (`p1/`)

### What to do
Create **2 virtual machines** with Vagrant. Install K3s on both so they form a Kubernetes cluster.

### The 2 machines

| | Machine 1 (Server) | Machine 2 (Worker) |
|--|--------------------|--------------------|
| **Name** | `<your_login>S` | `<your_login>SW` |
| **Example** | `abasseS` | `abasseSW` |
| **IP** | `192.168.56.110` | `192.168.56.111` |
| **K3s role** | Controller (server) | Agent (worker) |
| **CPU** | 1 | 1 |
| **RAM** | 512 MB or 1024 MB | 512 MB or 1024 MB |

### Files you need to write

| File | What to put inside |
|------|-------------------|
| `p1/Vagrantfile` | Ruby config that defines both VMs — names, IPs, resources, provisioning scripts |
| `p1/scripts/server.sh` | Shell script: install K3s in **server** mode. The token will be at `/var/lib/rancher/k3s/server/node-token` |
| `p1/scripts/worker.sh` | Shell script: install K3s in **agent** mode, using the server's IP (`192.168.56.110`) and token to join |

### What the evaluator will check
1. `vagrant up` starts both VMs without errors
2. SSH into the server: `vagrant ssh <login>S`
3. Run `kubectl get nodes` → both nodes show **Ready**
4. Both machines have the correct IPs (`ip a` command)

---

## Part 2: K3s and Three Simple Applications (`p2/`)

### What to do
Use **1 VM** with K3s. Deploy **3 web apps**. Use **Ingress** to route traffic by hostname.

### Routing rules

| When client uses this Host | Show this app | Number of replicas |
|---------------------------|---------------|-------------------|
| `app1.com` | app1 | 1 |
| `app2.com` | app2 | **3** |
| anything else (default) | app3 | 1 |

### Files you need to write

| File | What to put inside |
|------|-------------------|
| `p2/Vagrantfile` | 1 VM: `<login>S`, IP `192.168.56.110`, K3s server mode |
| `p2/scripts/server.sh` | Install K3s + apply all YAML configs from the `confs/` folder |
| `p2/confs/app1.yaml` | Kubernetes Deployment (1 replica) + Service for app1 |
| `p2/confs/app2.yaml` | Kubernetes Deployment (**3 replicas**) + Service for app2 |
| `p2/confs/app3.yaml` | Kubernetes Deployment (1 replica) + Service for app3 |
| `p2/confs/ingress.yaml` | Ingress resource with routing rules for app1.com, app2.com, and default |

### What the evaluator will check
1. `vagrant up` starts the VM
2. `curl -H "Host: app1.com" http://192.168.56.110` → shows app1
3. `curl -H "Host: app2.com" http://192.168.56.110` → shows app2
4. `curl http://192.168.56.110` → shows app3 (default)
5. `kubectl get pods` → app2 has 3 pods running
6. You must show the Ingress config to evaluators

---

## Part 3: K3d and Argo CD (`p3/`)

### What to do
1. Install **K3d** (K3s running in Docker — no more VMs!)
2. Install **Argo CD** for automated deployment
3. Create a **public GitHub repo** with your app config
4. Argo CD watches GitHub and auto-deploys to your cluster

### Two namespaces required

| Namespace | What goes here |
|-----------|---------------|
| `argocd` | Argo CD itself (the GitOps tool) |
| `dev` | Your application (deployed automatically by Argo CD) |

### The app — 2 versions

You choose one option:

| Option | Image | How |
|--------|-------|-----|
| **Use Wil's app** (easier) | `wil42/playground:v1` and `:v2` | Just reference it in your YAML |
| **Your own app** | Your Docker Hub image with `:v1` and `:v2` tags | Build, tag, and push to Docker Hub |

Both use **port 8888**.

### Files you need to write

| File | What to put inside |
|------|-------------------|
| `p3/scripts/setup.sh` | THE BIG SCRIPT: installs Docker, K3d, kubectl → creates cluster → creates namespaces → installs Argo CD → applies app config |
| `p3/confs/argocd.yaml` | Argo CD Application CRD: tells Argo CD which GitHub repo to watch and where to deploy |
| `p3/confs/deployment.yaml` | Kubernetes Deployment for the app — this ALSO goes in your public GitHub repo |

### The demo you must show

```
1. Run setup.sh → everything installs
2. curl localhost:8888 → {"status":"ok", "message": "v1"}
3. Change v1→v2 in your GitHub repo
4. Argo CD detects the change and re-deploys
5. curl localhost:8888 → {"status":"ok", "message": "v2"}
```

### What the evaluator will check
1. `setup.sh` runs and installs everything
2. `kubectl get ns` → `argocd` and `dev` namespaces exist
3. `kubectl get pods -n argocd` → Argo CD is running
4. `kubectl get pods -n dev` → app pod is running
5. App responds with v1
6. After GitHub update → app responds with v2
7. Argo CD UI shows the app synchronized

---

## Bonus: GitLab (`bonus/`)

### What to do
Add a **local GitLab** to replace GitHub in Part 3.

### Requirements
- GitLab runs in a `gitlab` namespace inside your cluster
- Argo CD connects to your **local GitLab** instead of GitHub
- Everything from Part 3 still works the same way
- Use the latest version of GitLab from the official website
- **Helm** is recommended for installing GitLab

### ⚠️ Warning
The subject says this bonus is **complex**. Only attempt it if your mandatory parts (p1, p2, p3) are **flawless** — meaning no bugs, no issues, everything works perfectly. If the mandatory parts have any problems, the bonus **will NOT be evaluated**.
