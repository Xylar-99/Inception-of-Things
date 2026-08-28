# Part 2: K3s + Three Applications + Ingress — Everything Explained

This document explains every file in `p2/`, why each choice was made, and how the whole system works together.

---

## What Part 2 Does

Part 2 runs a **single-node K3s cluster** on one virtual machine and deploys **3 web applications** behind a single Ingress controller. Traffic is routed by hostname:

| Host header | Application | Replicas |
|-------------|-------------|----------|
| `app1.com` | app1 | 1 |
| `app2.com` | app2 | 3 |
| anything else | app3 (default) | 1 |

K3s ships with **Traefik** built in as the Ingress controller, so no extra Ingress controller installation is required.

---

## File Overview

| File | Purpose |
|------|---------|
| `p2/Vagrantfile` | Defines the single VM (name, IP, resources) |
| `p2/scripts/server.sh` | Installs K3s and applies all Kubernetes configs |
| `p2/confs/app1.yaml` | ConfigMap + Deployment (1 replica) + Service for app1 |
| `p2/confs/app2.yaml` | ConfigMap + Deployment (3 replicas) + Service for app2 |
| `p2/confs/app3.yaml` | ConfigMap + Deployment (1 replica) + Service for app3 |
| `p2/confs/ingress.yaml` | Ingress resource with hostname-based routing rules |

---

## `p2/Vagrantfile`

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  config.vm.define "abquaoubS" do |server|
    server.vm.hostname = "abquaoubS"
    server.vm.network "private_network", ip: "192.168.56.110"
    server.vm.provider "virtualbox" do |vb|
      vb.name = "abquaoubS"
      vb.cpus = 1
      vb.memory = 1024
    end
    server.vm.provision "shell", path: "scripts/server.sh"
  end
end
```

### Why this setup

- **Single VM**: Part 2 only needs one machine because it is a single-node cluster. There is no worker separation needed.
- **`bento/ubuntu-24.04`**: A stable, widely used Ubuntu box that works well with VirtualBox and K3s.
- **Private network `192.168.56.110`**: This IP is used for all Ingress traffic. The evaluator sends HTTP requests to this IP with different `Host` headers.
- **1 vCPU / 1024 MB RAM**: Enough for K3s, Traefik, and 5 pods total. More than enough for nginx containers.
- **Provisioning with `server.sh`**: The shell script runs automatically when the VM boots. It installs K3s and applies all Kubernetes manifests.

---

## `p2/scripts/server.sh`

```bash
#!/bin/bash
set -e

apt-get update
apt-get install -y net-tools

curl -sfL https://get.k3s.io | \
    INSTALL_K3S_EXEC="server --write-kubeconfig-mode 644" \
    sh -

systemctl is-active --quiet k3s

echo "alias k=kubectl" >> /home/vagrant/.bashrc

cat /var/lib/rancher/k3s/server/node-token > /vagrant/k3s-token

while ! kubectl get nodes >/dev/null 2>&1; do
  sleep 2
done

kubectl apply -f /vagrant/confs/app1.yaml
kubectl apply -f /vagrant/confs/app2.yaml
kubectl apply -f /vagrant/confs/app3.yaml
kubectl apply -f /vagrant/confs/ingress.yaml
```

### What each section does

1. **`apt-get update && apt-get install -y net-tools`**
   Updates package lists and installs `net-tools` (provides `ifconfig`, `netstat`, etc.) so the user can inspect networking inside the VM.

2. **K3s installation**
   Downloads the official K3s install script and runs it in **server** mode.
   - `--write-kubeconfig-mode 644`: Allows the `vagrant` user to read the kubeconfig without `sudo`. This is important because Vagrant's default user is non-root.

3. **`systemctl is-active --quiet k3s`**
   Verifies that the K3s service started successfully. If it did not, the script fails fast.

4. **`alias k=kubectl`**
   Adds a convenience alias to `.bashrc` so the user can type `k` instead of `kubectl`.

5. **Token export**
   Writes the K3s node token to `/vagrant/k3s-token`. This makes the token available outside the VM through Vagrant's shared folder. (In Part 2 there is no worker, but the token is still exported for consistency with Part 1.)

6. **Wait loop + `kubectl apply`**
   K3s takes a few seconds to become fully ready after installation. The `while` loop waits until `kubectl get nodes` succeeds, then applies all four manifest files from the shared `/vagrant/confs/` folder.

### Why `kubectl apply` is in `server.sh`

The evaluator runs `vagrant up` and then checks the running cluster. If manifests are not applied automatically, the evaluator would have to SSH in and run commands manually. Putting `kubectl apply` in the provisioning script makes the setup fully reproducible with a single command.

---

## `p2/confs/app1.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app1-config
data:
  index.html: |
    <html><body><h1>App 1</h1></body></html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: app1
        image: nginx:latest
        ports:
        - containerPort: 80
        volumeMounts:
        - name: app1-volume
          mountPath: /usr/share/nginx/html/index.html
          subPath: index.html
      volumes:
      - name: app1-volume
        configMap:
          name: app1-config
---
apiVersion: v1
kind: Service
metadata:
  name: app1
spec:
  selector:
    app: app1
  ports:
  - port: 80
    targetPort: 80
```

### Why nginx + ConfigMap

- **nginx**: Lightweight, widely available, and serves HTTP on port 80 by default. It is the standard "hello world" container for Kubernetes demos.
- **ConfigMap with `index.html`**: Without a custom page, all three nginx apps would return the identical "Welcome to nginx!" page, making it impossible to verify which app is responding. The ConfigMap overrides the default `index.html` with unique content for each app.
- **`subPath: index.html`**: Mounts only the single file from the ConfigMap into the nginx document root, replacing the default page without hiding other nginx assets.
- **`replicas: 1`**: The subject explicitly requires 1 replica for app1.
- **Service type ClusterIP (default)**: Services are only exposed internally within the cluster. The Ingress controller (Traefik) reaches them through this ClusterIP.

---

## `p2/confs/app2.yaml`

```yaml
# Same structure as app1.yaml, but with replicas: 3
```

### Why 3 replicas

The subject explicitly states that app2 must run with **3 replicas**. This demonstrates Kubernetes scaling: one Deployment definition produces 3 identical Pods. The Service automatically load-balances across all 3 Pods.

This also lets the evaluator verify scaling by running:
```bash
kubectl get pods
```
and seeing 3 Pods with the `app=app2` label.

---

## `p2/confs/app3.yaml`

```yaml
# Same structure as app1.yaml, but with replicas: 1 and App 3 content
```

### Why app3 is the default

App3 is configured as the **default backend** in the Ingress resource. When a request arrives without a matching `Host` header (or with a host that is not `app1.com` or `app2.com`), the Ingress controller routes it to app3. This is implemented using `spec.defaultBackend` in the Ingress YAML.

---

## `p2/confs/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  rules:
  - host: app1.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1
            port:
              number: 80
  - host: app2.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2
            port:
              number: 80
  defaultBackend:
    service:
      name: app3
      port:
        number: 80
```

### Why this routing

- **Host-based routing**: The Ingress controller (Traefik) inspects the `Host` header of incoming HTTP requests.
  - `Host: app1.com` → Service `app1` → Pod running app1
  - `Host: app2.com` → Service `app2` → one of the 3 app2 Pods
  - No matching host → `defaultBackend` → Service `app3` → Pod running app3
- **`path: /` + `pathType: Prefix`**: Matches all paths on the given host.
- **No `ingressClassName` specified**: K3s installs Traefik as the default Ingress controller. Omitting the class allows the default controller to pick up this Ingress automatically.

### How the evaluator tests it

The evaluator runs these commands from their own machine (or from inside the VM) targeting the VM's IP `192.168.56.110`:

```bash
curl -H "Host: app1.com" http://192.168.56.110
# Expected: HTML containing "App 1"

curl -H "Host: app2.com" http://192.168.56.110
# Expected: HTML containing "App 2"

curl http://192.168.56.110
# Expected: HTML containing "App 3"
```

---

## How the Pieces Connect

```
Evaluator's curl
    │
    ▼
192.168.56.110 (VM IP)
    │
    ▼
Traefik (Ingress Controller, built into K3s)
    │
    ├── Host: app1.com ──► Service app1 ──► Pod app1 (1 replica, nginx + "App 1")
    │
    ├── Host: app2.com ──► Service app2 ──► Pod app2 (3 replicas, nginx + "App 2")
    │
    └── default ────────► Service app3 ──► Pod app3 (1 replica, nginx + "App 3")
```

---

## Why These Specific Choices

| Choice | Reason |
|--------|--------|
| **nginx image** | Lightweight, standard, no extra dependencies, serves HTTP on port 80 |
| **ConfigMap for index.html** | Makes each app visually distinguishable without rebuilding images |
| **Deployment + Service per app** | Standard Kubernetes pattern: Deployment manages Pod lifecycle, Service provides stable network identity |
| **ClusterIP Service type** | Services are internal; Ingress is the only external entry point |
| **Ingress without explicit class** | Lets K3s/Traefik default handle it; fewer things to misconfigure |
| **`subPath` mount** | Replaces only the default page, keeps other nginx assets working |
| **`kubectl apply` in `server.sh`** | Full automation: `vagrant up` is the only command the evaluator needs to run |

---

## Verification Checklist

After running `vagrant up` in `p2/`:

```bash
# 1. VM is running and K3s is active
vagrant ssh abquaoubS -c "sudo systemctl is-active k3s"

# 2. All pods are running
vagrant ssh abquaoubS -c "kubectl get pods"
# Expected: app1-xxxxx (1/1), app2-xxxxx (3/3), app3-xxxxx (1/1)

# 3. Services exist
vagrant ssh abquaoubS -c "kubectl get services"

# 4. Ingress exists and has an address
vagrant ssh abquaoubS -c "kubectl get ingress"

# 5. Routing works
curl -H "Host: app1.com" http://192.168.56.110
curl -H "Host: app2.com" http://192.168.56.110
curl http://192.168.56.110
```

---

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| Ingress returns 404 | Traefik not ready yet | Wait a minute after `vagrant up` and retry |
| `kubectl apply` fails | K3s not ready when script runs | The `while` loop in `server.sh` handles this |
| All apps return the same page | No ConfigMap override | Ensure the `index.html` ConfigMap is mounted correctly |
| `curl` from host fails | Firewall or VirtualBox network issue | Verify `192.168.56.110` is reachable with `ping` |
