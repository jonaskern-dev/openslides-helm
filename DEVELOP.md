# Development Roadmap

This document outlines planned features and improvements for the OpenSlides Helm chart.

## Current Status

**Stable:** v1.0.3 with OpenSlides 4.2.23
- Manual backup/restore process documented
- Manual migration finalization required
- Helm upgrade requires uninstall + reinstall for version changes

## Goals

1. **Seamless Helm Upgrades** - Make `helm upgrade` work without data loss
2. **Automated Migrations** - Automatically detect and run migrations
3. **Backup/Restore Integration** - Restore backups via Helm values
4. **Zero-Downtime Updates** - Rolling updates with health checks

---

## Phase 1: Automated Migrations

**Goal:** Automatically run database migrations after upgrades without manual intervention.

### Implementation Options

#### Option A: Post-Upgrade Hook Job (Recommended)
**Pros:**
- Runs automatically after every upgrade
- Native Helm hook mechanism
- Easy to implement

**Cons:**
- Runs on every upgrade (even if not needed)
- Blocks upgrade completion until done

**Implementation:**
```yaml
# templates/migration-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    "helm.sh/hook": post-upgrade,post-install
    "helm.sh/hook-weight": "5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: ghcr.io/openslides/openslides/openslides-backend:{{ .Values.global.imageTag }}
        command:
        - python
        - openslides_backend/migrations/migrate.py
        - finalize
        env: [...]
      restartPolicy: OnFailure
```

**Tasks:**
- [ ] Create migration job template
- [ ] Configure proper environment variables
- [ ] Add service account with necessary permissions
- [ ] Test migration job execution
- [ ] Handle migration failures gracefully
- [ ] Add option to disable auto-migration

---

#### Option B: Init Container in Backend Pods
**Pros:**
- Migrations run before app starts
- Per-deployment control

**Cons:**
- Runs on every pod restart
- Can cause race conditions with multiple replicas

**Tasks:**
- [ ] Add init container to backend deployments
- [ ] Implement migration locking mechanism
- [ ] Test with multiple replicas

---

## Phase 2: Automated Backup Before Upgrade

**Goal:** Automatically create backup before upgrades to enable rollback.

### Implementation Options

#### Option A: Pre-Upgrade Hook Job
**Pros:**
- Automatic safety net
- No user action required

**Cons:**
- Requires PVC for backup storage
- Increases upgrade time

**Implementation:**
```yaml
# templates/backup-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "-5"
spec:
  template:
    spec:
      containers:
      - name: backup
        image: postgres:15
        command:
        - pg_dump
        - -U
        - openslides
        - -d
        - openslides
        - -f
        - /backups/backup-$(date +%Y%m%d-%H%M%S).sql
        volumeMounts:
        - name: backups
          mountPath: /backups
      volumes:
      - name: backups
        persistentVolumeClaim:
          claimName: openslides-backups
```

**Tasks:**
- [ ] Create backup PVC template
- [ ] Implement pre-upgrade backup job
- [ ] Add retention policy (keep last N backups)
- [ ] Add option to skip backup
- [ ] Test backup restoration
- [ ] Document rollback procedure

---

## Phase 3: Backup Restore via Helm Values

**Goal:** Enable backup restore during installation via Helm values.

### Implementation

**Values Configuration:**
```yaml
restore:
  enabled: false
  source: "pvc"  # or "url", "configmap"

  # For PVC source
  pvc:
    name: "openslides-backups"
    filename: "backup-20251017.sql"

  # For URL source
  url: "https://example.com/backup.sql"

  # For ConfigMap source
  configMap:
    name: "openslides-backup"
    key: "backup.sql"

  # Auto-migrate after restore
  autoMigrate: true
```

**Restore Job:**
```yaml
# templates/restore-job.yaml
{{- if .Values.restore.enabled }}
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    "helm.sh/hook": post-install
    "helm.sh/hook-weight": "1"
spec:
  template:
    spec:
      initContainers:
      # 1. Download/copy backup
      - name: fetch-backup
        [...]
      # 2. Drop schemas
      - name: drop-schemas
        image: postgres:15
        command:
        - psql
        - -U
        - openslides
        - -d
        - openslides
        - -c
        - "DROP SCHEMA IF EXISTS public CASCADE; ..."
      containers:
      # 3. Restore backup
      - name: restore
        image: postgres:15
        command:
        - psql
        - -U
        - openslides
        - -d
        - openslides
        - -f
        - /backup/backup.sql
{{- end }}
```

**Tasks:**
- [ ] Implement restore job with multiple sources
- [ ] Add pre-restore schema cleanup
- [ ] Integrate with migration job (post-restore)
- [ ] Add validation checks
- [ ] Test all restore sources (PVC, URL, ConfigMap)
- [ ] Document restore process
- [ ] Add restore from S3/cloud storage

---

## Phase 4: Improved Helm Upgrade Experience

**Goal:** Make `helm upgrade` work without requiring uninstall + reinstall.

### Challenges

1. **Secret Regeneration**
   - Current: pre-install hook regenerates secrets
   - Problem: On upgrade, secrets don't exist yet
   - Solution: Use `helm.sh/hook: pre-install` only, not pre-upgrade

2. **Database Password Mismatch**
   - Current: New secrets → Database has old password → Connection fails
   - Solution: Never regenerate secrets on upgrade

3. **Version Changes**
   - Current: Image tag changes require pod restart
   - Solution: Already works with rolling updates

### Implementation

**Tasks:**
- [ ] Modify secret-generator job to skip on upgrade
- [ ] Add secret existence check in hook
- [ ] Test upgrade with existing secrets
- [ ] Document secret management for upgrades
- [ ] Add option to rotate secrets manually

**Hook Annotation Update:**
```yaml
# templates/secret-generator-job.yaml
annotations:
  "helm.sh/hook": pre-install  # Remove pre-upgrade
```

---

## Phase 5: Zero-Downtime Updates

**Goal:** Update OpenSlides without service interruption.

### Implementation

**Tasks:**
- [ ] Add readiness probes to all deployments
- [ ] Add liveness probes to all deployments
- [ ] Configure proper rolling update strategy
- [ ] Test rolling updates with active users
- [ ] Add pre-stop lifecycle hooks for graceful shutdown
- [ ] Document zero-downtime upgrade procedure

**Rolling Update Strategy:**
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

---

## Phase 6: Monitoring & Observability

**Goal:** Add monitoring and alerting capabilities.

### Features

- [ ] Prometheus metrics endpoints
- [ ] Grafana dashboard template
- [ ] Health check endpoints
- [ ] Migration status metrics
- [ ] Backup success/failure alerts

---

## Phase 7: Additional Chart Variants

**Goal:** Support different Kubernetes environments.

### Planned Charts

- [ ] **openslides-k8s-nginx** - Standard Kubernetes with nginx ingress
- [ ] **openslides-k8s-istio** - Kubernetes with Istio service mesh
- [ ] **openslides-standalone** - Without ingress controller

---

## Technical Debt & Improvements

### High Priority
- [ ] Add automated tests (helm unittest)
- [ ] Add CI/CD pipeline for chart testing
- [ ] Improve secret management (External Secrets Operator support)
- [ ] Add support for custom CA certificates

### Medium Priority
- [ ] Add resource quota recommendations
- [ ] Improve documentation with diagrams
- [ ] Add troubleshooting guide
- [ ] Add performance tuning guide

### Low Priority
- [ ] Add support for horizontal pod autoscaling
- [ ] Add network policies
- [ ] Add pod security policies
- [ ] Multi-tenancy support

---

## Testing Strategy

### Required Tests

1. **Fresh Installation**
   - [ ] Default values
   - [ ] With TLS enabled
   - [ ] With email enabled
   - [ ] All pods running and healthy

2. **Upgrade Tests**
   - [ ] Minor version upgrade (4.2.11 → 4.2.23)
   - [ ] Chart upgrade (1.0.2 → 1.0.3)
   - [ ] With existing data
   - [ ] Automatic migrations

3. **Backup/Restore Tests**
   - [ ] Backup creation
   - [ ] Restore from PVC
   - [ ] Restore from URL
   - [ ] Restore from ConfigMap
   - [ ] Post-restore migrations

4. **Failure Scenarios**
   - [ ] Migration failure
   - [ ] Backup failure
   - [ ] Database connection issues
   - [ ] Resource exhaustion

---

## Open Questions

1. **Secret Rotation:** How to handle secret rotation for existing installations?
2. **Multi-Cluster:** Support for multi-cluster deployments?
3. **High Availability:** PostgreSQL HA setup?
4. **Disaster Recovery:** Off-site backup strategy?

---

## Contributing

If you want to contribute to any of these features:

1. Check this document for open tasks
2. Create an issue to discuss the implementation
3. Submit a PR with your changes
4. Update this document with progress

---

## Timeline

**Q4 2025:**
- Phase 1: Automated Migrations
- Phase 2: Automated Backup

**Q1 2026:**
- Phase 3: Backup Restore Integration
- Phase 4: Improved Helm Upgrade

**Q2 2026:**
- Phase 5: Zero-Downtime Updates
- Phase 6: Monitoring

**Future:**
- Phase 7: Additional Chart Variants
- Technical Debt Resolution

---

## Notes

- All features should be optional and disabled by default
- Backward compatibility must be maintained
- Changes should not break existing installations
- Documentation must be updated with each feature
