# 🧠 Concepts Explained — Why Each Tool Exists

---

## 1. What is Kubernetes (K8s)?

Kubernetes manages your apps across multiple servers automatically.

**Without K8s:** Your app runs on 1 server. If it crashes → app is down.
**With K8s:** Your app runs on multiple servers. If one crashes → others keep running. K8s restarts the dead one.

| Feature | What it means |
|---------|-------------|
| Self-healing | Container crashes → K8s restarts it |
| Scaling | Set `replicas: 5` → K8s runs 5 copies |
| Load balancing | Traffic is split across all copies |
| Rolling updates | Update app with zero downtime |

---

## 2. What is K3s? (Why not full K8s?)

**K3s = lightweight Kubernetes.** Full K8s needs lots of RAM and complex setup. K3s is a single binary, needs ~512MB RAM, installs with one command.

```
Full K8s: heavy, complex, for big production
K3s: light, simple, for learning/edge/IoT
```

**Two modes:**
- **Server (controller):** The brain. Runs the API, makes decisions.
- **Agent (worker):** The muscle. Joins the cluster, runs your containers.

---

## 3. What is Vagrant? (Why do we need it?)

**Problem:** Manually creating VMs is slow, error-prone, and not reproducible.

**Solution:** Vagrant lets you define VMs in a text file (`Vagrantfile`). One command creates everything:

```bash
vagrant up       # Create + start all VMs
vagrant ssh      # Connect to a VM
vagrant destroy  # Delete everything
```

**Why this project needs it:** The evaluator runs `vagrant up` and gets the exact same setup as you. Reproducible!

**Vagrant needs a hypervisor** (like VirtualBox) to actually create the VMs. Vagrant = steering wheel, VirtualBox = engine.

---

## 4. What is K3d? (How is it different from K3s?)

K3d runs K3s **inside Docker containers** instead of full VMs.

| | K3s (Parts 1 & 2) | K3d (Part 3) |
|--|-------------------|-------------|
| Runs in | Virtual Machines | Docker containers |
| Start time | Minutes | Seconds |
| Resources | Heavy (full OS each) | Light (shared kernel) |
| Needs | Vagrant + VirtualBox | Just Docker |

```bash
k3d cluster create mycluster   # Cluster ready in seconds
k3d cluster delete mycluster   # Gone in seconds
```

---

## 5. What is Docker?

Docker runs apps in **containers** — isolated packages with everything the app needs.

| Concept | What it is |
|---------|-----------|
| **Image** | Blueprint/recipe (like a class) |
| **Container** | Running instance (like an object) |
| **Docker Hub** | Online image store (like GitHub for images) |
| **Tag** | Version label (e.g., `wil42/playground:v1`) |

---

## 6. Kubernetes Core Objects (the YAML files)

### Deployment
"Run X copies of this container and keep them alive."

### Service
"Give my pods a stable address so others can find them."

### Ingress
"Route incoming HTTP traffic to the right Service based on hostname."

### Namespace
"A folder to organize things in the cluster." (e.g., `argocd`, `dev`)

### How they connect:
```
User request → Ingress → Service → Pod(s) → Your App
                 ↑ routes    ↑ finds    ↑ runs
              by hostname  by label   container
```

---

## 7. What is Ingress? (The traffic router)

**Problem:** 3 apps share 1 IP. How does K8s know which app to show?

**Solution:** Ingress looks at the **Host header** and routes to the right app.

```
Client says Host: app1.com  →  Ingress sends to app1
Client says Host: app2.com  →  Ingress sends to app2
Client says nothing special →  Ingress sends to app3 (default)
```

**Analogy:** A hotel receptionist. "Here for the wedding?" → Ballroom. "Conference?" → Room B. Otherwise → Lobby.

K3s comes with **Traefik** as its Ingress Controller built-in.

---

## 8. What is Argo CD and GitOps?

### GitOps = Git is the source of truth
Whatever is in your Git repo = what runs in your cluster.

### Argo CD = the tool that enforces GitOps
1. **Watches** your GitHub repo
2. **Compares** repo vs cluster
3. **Syncs** cluster to match repo

```
You push v2 to GitHub
   → Argo CD detects change
   → Argo CD deploys v2 to cluster
   → App now runs v2
```

---

## 9. What is Helm? (Bonus only)

**Helm = package manager for Kubernetes** (like apt for Ubuntu).

Instead of writing 50 YAML files to install GitLab:
```bash
helm install gitlab gitlab/gitlab   # One command
```

---

## 10. How Everything Connects

```
Part 1: VirtualBox ← Vagrant ← creates VMs ← run K3s
Part 2: Same + Deployments + Services + Ingress
Part 3: Docker ← K3d ← creates K3s ← Argo CD ← watches GitHub
Bonus:  Helm ← installs GitLab ← replaces GitHub
```
