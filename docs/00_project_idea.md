# Project Idea Explained

This project is not about building one big application.
It is about learning how to create, run, and connect applications using Kubernetes.

The main idea is:
- create machines or clusters
- install Kubernetes on them
- deploy simple apps
- expose them with networking rules
- automate deployments with GitOps

So the project is really about **infrastructure and deployment**, not about app features.

---

## Why does Part 1 use two machines?

Part 1 uses **two virtual machines** to simulate a real Kubernetes cluster.

### Machine 1: server
- acts like the brain of the cluster
- controls the Kubernetes API
- decides where workloads should run

### Machine 2: worker
- acts like the machine that does the real work
- runs the containers and pods

This setup is important because Kubernetes is made to manage more than one machine.
Using two VMs helps you understand how a cluster works in real life.

### Simple analogy
- server = manager
- worker = employee

The manager decides what should happen.
The employee actually does the job.

---

## What the project is trying to teach

### 1. Cluster basics
You learn how to create a Kubernetes cluster from scratch.

### 2. Networking
You learn how traffic reaches the correct app using Service and Ingress.

### 3. Deployment
You learn how to define apps with YAML files instead of clicking buttons.

### 4. Scaling
You learn how to run multiple copies of the same app.

### 5. Automation
You learn how Git can become the source of truth for deployments.

---

## What each part means

### Part 1
Create a small cluster with 2 VMs:
- one server
- one worker

This proves that Kubernetes can manage multiple machines.

### Part 2
Run 3 apps on 1 VM and use Ingress to send users to the right app.

This teaches routing by hostname, like:
- `app1.com` -> app1
- `app2.com` -> app2
- default -> app3

### Part 3
Create a cluster with K3d and use Argo CD.

This teaches GitOps:
- you change files in Git
- Argo CD sees the change
- the cluster updates automatically

### Bonus
Replace GitHub with GitLab.

This is a harder extra challenge.

---

## What "app" means here

In this project, an app is usually a very small web service.
It does not need to be a complex product.
It is just something Kubernetes can run and expose.

Examples:
- a test web page
- a small HTTP server
- a simple demo container

The goal is to understand the deployment flow, not to build a big feature.

---

## Full project idea in one sentence

Build a small Kubernetes environment step by step, starting from two virtual machines and ending with automated Git-based deployments.

---

## Short summary for beginners

If you are wondering "What is this project for?", the answer is:

It teaches how real DevOps and Kubernetes setups work, using small machines and simple apps so you can focus on the infrastructure.
