# OpenSlides Helm Chart for k3s/k3d with Traefik

A production-ready Helm chart for deploying [OpenSlides](https://openslides.com/) on k3s/k3d clusters with native Traefik integration.

## Features

- Native k3s/k3d support with Traefik IngressRoutes
- Automatic TLS certificate management via cert-manager (optional)
- Auto-generation of secure secrets with password display
- Conditional email features (disabled if no password provided)
- PostgreSQL and Redis included
- Configurable resource limits and replica counts
- Support for multiple environments (dev, staging, production)

## Prerequisites

- Kubernetes cluster (k3s, k3d, or compatible)
- Helm 3.x
- Traefik ingress controller (usually pre-installed in k3s/k3d)
- **Optional:** [cert-manager](https://cert-manager.io/) for automatic TLS certificate management

## Quick Start

### Option A: Using Helm Repository (Recommended)

```bash
# Add the Helm repository
helm repo add openslides https://jonaskern-dev.github.io/openslides-helm
helm repo update

# Install the chart
helm install openslides openslides/openslides-k3s-traefik \
  -f my-values.yaml \
  -n openslides \
  --create-namespace
```

### Option B: From Source

```bash
# Clone the repository
git clone https://github.com/jonaskern-dev/openslides-helm
cd openslides-helm

# Install the chart
helm install openslides ./charts/openslides-k3s-traefik \
  -f my-values.yaml \
  -n openslides \
  --create-namespace
```

### 1. Create your values file

Create a `my-values.yaml` file:

```yaml
global:
  domain: openslides.example.com

# Optional: Enable email features
secrets:
  emailPassword: "your-smtp-password"

# Optional: Configure TLS with cert-manager
tls:
  issuer: "letsencrypt-prod"  # Your ClusterIssuer name
```

### 2. Get the generated admin password

```bash
kubectl get secret openslides-openslides-k3s-traefik-secrets -n openslides \
  -o jsonpath='{.data.superadmin}' | base64 -d && echo
```

## Configuration

### TLS/Certificate Management

The chart supports two modes for TLS certificates:

#### Option A: Automatic with cert-manager (Recommended)

1. Install cert-manager in your cluster:
   ```bash
   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
   ```

2. Create a ClusterIssuer (e.g., for Let's Encrypt):
   ```yaml
   apiVersion: cert-manager.io/v1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-prod
   spec:
     acme:
       server: https://acme-v02.api.letsencrypt.org/directory
       email: your-email@example.com
       privateKeySecretRef:
         name: letsencrypt-prod
       solvers:
       - http01:
           ingress:
             class: traefik
   ```

3. Configure in your values file:
   ```yaml
   tls:
     enabled: true
     issuer: "letsencrypt-prod"
   ```

#### Option B: Manual TLS Secret

If you don't use cert-manager, create the TLS secret manually:

```bash
kubectl create secret tls openslides-tls \
  --cert=path/to/cert.pem \
  --key=path/to/key.pem \
  -n openslides
```

Configure in values:
```yaml
tls:
  enabled: true
  issuer: ""  # Leave empty for manual mode
  secretName: "openslides-tls"
```

### Secrets Management

The chart automatically generates secure secrets if not provided:

- `authTokenKey`, `authCookieKey`, `internalAuthPassword`, `manageAuthPassword`
- `superadmin` (displayed after installation)
- `postgresPassword` (displayed after installation)

**Email Password** is optional - if not provided, email features will be disabled.

To provide custom secrets:

```yaml
secrets:
  superadmin: "my-custom-admin-password"
  emailPassword: "my-smtp-password"
  # Leave others empty for auto-generation
```

### Email Configuration

Email is optional. To enable:

```yaml
secrets:
  emailPassword: "your-smtp-password"

email:
  host: "smtp.example.com"
  port: 587
  user: "openslides@example.com"
  from: "openslides@example.com"
  security: "STARTTLS"  # or "SSL/TLS"
```

If `emailPassword` is not set, email features will be disabled with a warning.

### Resource Limits

Adjust resource limits for your environment:

```yaml
resources:
  client:
    limits: {cpu: 500m, memory: 512Mi}
    requests: {cpu: 100m, memory: 128Mi}
  backend:
    limits: {cpu: 1000m, memory: 1Gi}
    requests: {cpu: 200m, memory: 256Mi}
  datastore:
    limits: {cpu: 500m, memory: 512Mi}
    requests: {cpu: 100m, memory: 128Mi}
```

### Replica Counts

Scale services independently:

```yaml
services:
  client:
    replicas: 2
  backendAction:
    replicas: 2
  datastoreReader:
    replicas: 2
    workers: 8
  # ... etc
```

## Upgrading

```bash
helm upgrade openslides . -f my-values.yaml -n openslides
```

Secrets will be preserved during upgrades.

## Uninstalling

```bash
helm uninstall openslides -n openslides
```

**Note:** PersistentVolumes may need to be manually deleted.

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n openslides
```

### View logs
```bash
kubectl logs -n openslides -l app=client
kubectl logs -n openslides -l app=backendaction
```

### Check certificate status (if using cert-manager)
```bash
kubectl get certificate -n openslides
kubectl describe certificate openslides-tls -n openslides
```

### Common Issues

**Pods crashing:** Check database connectivity and secrets
```bash
kubectl logs -n openslides <pod-name>
kubectl get secret openslides-openslides-k3s-traefik-secrets -n openslides
```

**Certificate not issued:** Verify ClusterIssuer exists and DNS is configured
```bash
kubectl get clusterissuer
kubectl describe certificate openslides-tls -n openslides
```

## Support

- **OpenSlides Documentation:** https://openslides.com/docs/
- **Chart Repository:** https://github.com/jonaskern-dev/openslides-helm
- **Issues:** https://github.com/jonaskern-dev/openslides-helm/issues

## License

MIT License - see LICENSE file for details.

## Maintainer

- Jonas Kern - https://jonaskern.dev
