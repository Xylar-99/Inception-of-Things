# Inception of Things

This repository contains the implementation of the Inception of Things project, divided into multiple parts:

- Part 1: Vagrant + K3s cluster setup
- Part 2: K3s + Ingress + 3 applications
- Part 3: K3d + Argo CD GitOps deployment
- Bonus: GitLab-based setup

The project is designed to teach Kubernetes orchestration, cluster setup, application deployment, and GitOps workflows using local virtual machines and containers.

---

## Project structure

- `p1/` — first Kubernetes cluster with 2 VMs
- `p2/` — single-node K3s cluster with 3 apps behind ingress
- `p3/` — K3d + Argo CD deployment flow
- `bonus/` — advanced GitLab bonus challenge
- `docs/` — subject explanations and learning resources

---

## Required machine / environment

You need a computer with enough resources to run virtual machines and containers.

### Minimum recommended hardware

- CPU: 4 cores or more
- RAM: 8 GB minimum
- Storage: at least 50 GB free
- Internet connection for downloading boxes, Kubernetes tools, and Docker images

### Required software

1. VirtualBox
   - Download and install: https://www.virtualbox.org/
   - This is required for the Vagrant-based VMs in Part 1 and Part 2.

2. Vagrant
   - Download and install: https://developer.hashicorp.com/vagrant/docs/installation
   - Vagrant is used to create and manage the virtual machines.

3. Git
   - Install Git and configure your username/email.

4. SSH client
   - Usually already available on Linux/macOS.
   - On Windows, use Git Bash or WSL2.

5. Docker
   - Required for Part 3 (K3d and container runtime)
   - Install Docker Desktop or Docker Engine.

6. kubectl
   - Required to interact with the Kubernetes cluster.

7. k3d
   - Required for Part 3, because the project uses a lightweight Kubernetes cluster in Docker.

8. Optional: Argo CD CLI
   - Useful but not always required if you use kubectl and the web UI.

---

## Recommended OS

This project is easiest to run on:

- Linux
- macOS
- Windows with WSL2 + Docker + VirtualBox

If you are on Windows without WSL2, the setup can become more difficult because Vagrant and Linux VM networking are more fragile.

---

## Part 1: K3s with 2 VMs

Folder: `p1/`

### What it does
- Creates 2 VirtualBox VMs
- Installs K3s in a cluster
- One VM acts as the server/controller
- One VM acts as the worker/agent

### VM setup

- Server VM: `192.168.56.110`
- Worker VM: `192.168.56.111`

### Typical commands

```bash
cd p1
vagrant up
vagrant ssh <your_login>S
kubectl get nodes
```

This part is meant to prove that the Kubernetes cluster is working and that both nodes are ready.

---

## Part 2: K3s + 3 applications + ingress

Folder: `p2/`

### What it does
- Runs a small K3s server on a VM
- Deploys 3 apps
- Uses ingress routing by hostname

### Expected routing

- `app1.com` -> app1
- `app2.com` -> app2
- default host -> app3

### Typical commands

```bash
cd p2
vagrant up
vagrant ssh <your_login>S
kubectl get pods
kubectl get ingress
```

---

## Part 3: K3d + Argo CD

Folder: `p3/`

### What it does
- Creates a K3d cluster using Docker
- Installs Argo CD
- Deploys application manifests from GitHub or a Git repository
- Demonstrates GitOps by updating the app version and letting Argo CD sync it

### Required tools for this part

- Docker
- k3d
- kubectl
- GitHub repository (or another Git remote)

### Typical command

```bash
cd p3
bash scripts/setup.sh
```

This part is designed to show the flow:

1. install cluster tools
2. create namespaces
3. deploy Argo CD
4. connect to Git repo
5. let Argo CD deploy the app
6. update the app version and let GitOps sync the change

---

## Bonus: GitLab

Folder: `bonus/`

This bonus is a more advanced version of Part 3, where GitLab is used instead of GitHub. It is meant for students who already have the mandatory parts working well.

This bonus is optional and more complex.

---

## Important notes

### Generated files that should not be pushed

This repository is configured to ignore local artifacts such as:

- `.vagrant/`
- `*.log`
- `.DS_Store`
- editor files
- temporary files
- local environment files

These files are created by VirtualBox, Vagrant, Docker, and your local environment and should not be committed to Git.

### Before starting

Run these checks first:

```bash
vagrant --version
virtualbox --help
kubectl version --client
docker --version
k3d version
```

If any command is missing, install the missing tool before continuing.

---

## Suggested order of work

1. Install VirtualBox and Vagrant
2. Complete Part 1
3. Complete Part 2
4. Install Docker and K3d
5. Complete Part 3
6. Try the bonus only after the main parts work

---

## Useful links

- VirtualBox: https://www.virtualbox.org/
- Vagrant: https://developer.hashicorp.com/vagrant
- Docker: https://www.docker.com/
- kubectl: https://kubernetes.io/docs/tasks/tools/
- K3d: https://k3d.io/
- Argo CD: https://argo-cd.readthedocs.io/

---

## Final note

This project is a practical Kubernetes lab. The main goal is to understand how local clusters are created, how services are exposed, and how GitOps can automate deployments.

If you run into issues, check the files inside `docs/` first. They explain the full project in simple language and describe the expected behavior for each part.
