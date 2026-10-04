# Project review report

This report distinguishes problems visible in the source from behavior that still needs deployment testing. No installation or provisioning scripts were executed for this review.

## Bonus fix completed

`bonus/scripts/setup.sh` now passes direct strings to the GitLab dependency helper:

| Helper setting | Value | Basis |
| --- | --- | --- |
| `VALKEY_CHART_VERSION` | `0.12.0` | Chart archive already present in the local GitLab helper cache. |
| `CNPG_CHART_VERSION` | `0.29.0` | Chart archive already present in the local GitLab helper cache. |
| `CNPG_POSTGRESQL_TAG` | `17` | Default in the pinned GitLab development helper. |
| `GARAGE_APP_VERSION` | `2.2.0` | Default in the pinned GitLab development helper. |

The undefined references to `VALKEY_VERSION`, `CNPG_VERSION`, `POSTGRES_VERSION`, and `GARAGE_VERSION` were removed. This fixes the unbound-variable failure; it does not prove that the full GitLab installation succeeds. The chart versions above reuse locally cached versions rather than claiming upstream guarantees of compatibility.

The user's removal of the cluster-deletion command is preserved. Bonus setup now expects a new cluster and fails at creation if `iot-bonus` already exists.

Upstream helper sources for GitLab chart `v10.4.1`: [development helper](https://gitlab.com/gitlab-org/charts/gitlab/-/blob/v10.4.1/scripts/dev_dependencies.sh), [Valkey](https://gitlab.com/gitlab-org/charts/gitlab/-/blob/v10.4.1/scripts/ci/lib/valkey.sh), [CloudNativePG](https://gitlab.com/gitlab-org/charts/gitlab/-/blob/v10.4.1/scripts/ci/lib/cloudnativepg.sh), and [Garage](https://gitlab.com/gitlab-org/charts/gitlab/-/blob/v10.4.1/scripts/ci/lib/garage.sh).

## Part 1

| Finding | Effect / verification needed |
| --- | --- |
| Worker token wait has no timeout. | Provisioning hangs if the server fails or the token never reaches the worker. |
| Token transfer depends on `/vagrant` sharing between both VMs. | Verify the actual libvirt shared-folder behavior; a server-written file must become visible on the worker. |
| K3s does not explicitly choose the private node IP or Flannel interface. | Verify node addresses and cross-node networking with the provider's management and private interfaces. This is a runtime concern, not a confirmed failure. |
| Install pipelines use `set -e` without `pipefail`. | A failed installer download can be masked by the downstream shell's exit status. |
| Only `net-tools` is explicitly installed. | Provisioning assumes the box already includes `curl`. |
| Agent gets a kubectl alias without kubeconfig setup. | The alias alone does not allow Kubernetes inspection from the agent; use the server. |
| Server kubeconfig is mode `644`; join token is in the shared folder. | Other local users may access cluster credentials. Keep generated tokens out of Git. |

Expected runtime check: both nodes are Ready, and workloads can communicate between them. The configuration alone does not establish this.

## Part 2

| Finding | Effect / verification needed |
| --- | --- |
| Kubernetes API wait has no timeout. | Provisioning hangs if the API never becomes available. |
| No deployment or ingress readiness wait. | The completion message can appear before applications accept requests. |
| Installer pipeline lacks `pipefail` and assumes `curl` exists. | Download failures may be hidden; a missing curl dependency breaks installation. |
| Most command errors are redirected to `/dev/null`. | Provisioning failure is harder to diagnose. |
| Nginx uses `latest`; K3s is unpinned. | Different runs can deploy different versions. |
| VM shares the server name and IP used in part 1. | Run these parts separately to avoid conflicts. |

Manifest selectors and service backend names are consistent. Verify HTTP routing for `app1.com`, `app2.com`, and an unmatched host, plus the three replicas of App 2.

## Part 3

| Finding | Effect / verification needed |
| --- | --- |
| Wait for Service `playground` has no timeout. | Setup hangs if Git sync fails or the remote manifests use another name. |
| Application manifests live in another repository. | Service name, pod labels, image versions, and application ingress cannot be verified from this project alone. |
| Cluster creation assumes `iot-p3` does not exist. | Rerunning setup is not idempotent. |
| Initial Argo CD wait covers only its server deployment. | Other controllers may still be starting when the Application is submitted. |
| Downloads kubectl for Linux amd64 only. | Fresh installation is unsuitable for ARM hosts. |
| Latest/default Docker, kubectl, and k3d versions are installed. | Version compatibility and reproducibility require runtime verification. |

Creating the external application's Kubernetes resources is expected GitOps behavior. Verify the Argo CD Application becomes Synced and Healthy and `http://app.iot.local` works.

## Bonus: remaining concerns

| Finding | Effect / verification needed |
| --- | --- |
| Cluster creation assumes `iot-bonus` does not exist. | Rerunning setup fails at creation; it no longer automatically deletes the cluster. |
| App Application is submitted before GitLab is ready. | Initial repository connection errors are expected until GitLab and the repository are available. |
| Only Argo CD server availability is initially checked. | Full Argo CD readiness is not established at that point. |
| Dependency setup retries after any failure by waiting for PostgreSQL. | Valkey, Garage, download, or Helm failures may be obscured by a subsequent database wait failure. |
| GitLab dependencies use upstream development helpers and a patched Garage script. | These depend on the pinned source layout and require an actual installation test. |
| No GitLab resource budget is documented or configured for the host. | Scheduling and startup can fail on a host with insufficient memory, CPU, or storage. |
| kubectl download targets amd64; tools are partly unpinned. | Architecture support and version compatibility need verification. |

Manually creating `iot/abquaoub-iot`, pushing `main` with `manifests/`, and making it readable by Argo CD are expected steps, not defects in the agreed workflow. Private projects require repository credentials. Application ingress must come from those manifests.

Part 3 and the bonus both publish host port 80 and use the same local Argo CD/application hostnames; run one at a time.

## Validation and limits

- Earlier review: all seven Bash scripts passed syntax checks; both Vagrantfiles passed Ruby syntax checks and `vagrant validate`; all nine YAML files parsed successfully.
- After the bonus fix: Bash syntax and the dependency helper's literal environment assignments were checked without running the helper or touching a cluster.
- No full deployment, Helm installation, remote application review, or assignment compliance assessment was performed.
