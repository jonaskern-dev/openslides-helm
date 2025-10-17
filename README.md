# OpenSlides Helm Charts

Helm charts for deploying [OpenSlides](https://openslides.com) on Kubernetes.

## Available Charts

### [openslides-k3s-traefik](charts/openslides-k3s-traefik/)

Production-ready Helm chart for deploying OpenSlides 4.x on k3s/k3d clusters with native Traefik IngressRoute support.

**Features:**
- Native k3s/k3d support with Traefik IngressRoutes
- Automatic TLS via cert-manager (optional)
- Auto-generation of secure secrets
- PostgreSQL with persistent storage
- Redis for cache and message bus
- All 17 OpenSlides microservices
- Health checks and resource limits

**Quick Start:**

```bash
# Add Helm repository
helm repo add openslides https://jonaskern-dev.github.io/openslides-helm
helm repo update

# Install chart
helm install openslides openslides/openslides-k3s-traefik \
  --set global.domain=openslides.example.com \
  --set tls.issuer=letsencrypt-prod \
  --namespace openslides \
  --create-namespace
```

[View full documentation →](charts/openslides-k3s-traefik/README.md)

## Development

### Local Installation

```bash
# Clone repository
git clone https://github.com/jonaskern-dev/openslides-helm.git
cd openslides-helm

# Install from local chart
helm install openslides ./charts/openslides-k3s-traefik \
  -f charts/openslides-k3s-traefik/values-dev.yaml \
  --namespace openslides \
  --create-namespace
```

### Chart Structure

```
openslides-helm/
├── charts/
│   └── openslides-k3s-traefik/    # k3s/k3d with Traefik
│       ├── Chart.yaml
│       ├── values.yaml
│       ├── templates/
│       └── README.md
└── .github/workflows/
    └── release.yaml                # Automated releases
```

## Contributing

**Contributions are welcome!**

Future charts for different Kubernetes environments are planned:
- `openslides-k8s-nginx` - Standard Kubernetes with nginx ingress
- `openslides-k8s-istio` - Kubernetes with Istio service mesh
- `openslides-standalone` - Without ingress controller

If you'd like to contribute a chart for another Kubernetes setup or improve existing ones, feel free to:
- Open an issue to discuss your idea
- Submit a pull request with your chart
- Report bugs or suggest improvements

All contributions are appreciated!

## License

MIT License - see [LICENSE](charts/openslides-k3s-traefik/LICENSE) for details.

## Links

- [OpenSlides Official Website](https://openslides.com)
- [OpenSlides GitHub](https://github.com/OpenSlides/OpenSlides)
- [Chart Repository](https://jonaskern-dev.github.io/openslides-helm)
