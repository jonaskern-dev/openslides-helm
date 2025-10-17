# Upgrade Guide

This guide covers upgrading OpenSlides between versions using this Helm chart.

## Table of Contents

- [Overview](#overview)
- [Before You Upgrade](#before-you-upgrade)
- [Upgrade Process](#upgrade-process)
- [Browser Cache](#browser-cache)
- [Troubleshooting](#troubleshooting)

## Overview

**Recommended approach for version upgrades:** Clean installation with backup restore.

This approach has been tested and verified for OpenSlides version upgrades (e.g., 4.2.11 → 4.2.23).

## Before You Upgrade

⚠️ **CRITICAL: Create backup BEFORE uninstalling!**

If you uninstall without backing up first, **all data will be permanently lost**.

```bash
# Create PostgreSQL backup
kubectl exec postgres-0 -n <namespace> -- \
  pg_dump -U openslides -d openslides > openslides-backup-$(date +%Y%m%d).sql

# Verify backup file exists and has content
ls -lh openslides-backup-*.sql
head -20 openslides-backup-*.sql
```

**Keep this backup file safe until the upgrade is complete and verified!**

## Upgrade Process

### Step 1: Create Backup

⚠️ **DO THIS FIRST - Before uninstalling!**

```bash
# Create backup with timestamp
kubectl exec postgres-0 -n <namespace> -- \
  pg_dump -U openslides -d openslides > openslides-backup-$(date +%Y%m%d-%H%M%S).sql

# Verify backup
ls -lh openslides-backup-*.sql

# IMPORTANT: Keep this file safe!
```

### Step 2: Uninstall Current Release

**Only proceed after backup is created and verified!**

```bash
# Uninstall Helm release
helm uninstall openslides -n <namespace>

# Delete PersistentVolumeClaims
kubectl delete pvc data-postgres-0 backups-postgres-0 -n <namespace>
```

### Step 3: Install New Version

```bash
# Update Helm repository
helm repo update

# Install with new version
helm install openslides openslides/openslides-k3s-traefik \
  -n <namespace> \
  --create-namespace \
  -f your-values.yaml \
  --set global.imageTag=4.2.23
```

Wait for all pods to be running:

```bash
kubectl get pods -n <namespace> -w
```

### Step 4: Restore Backup

```bash
# Copy backup to PostgreSQL pod
kubectl cp openslides-backup-*.sql <namespace>/postgres-0:/tmp/backup.sql

# Drop existing schemas
kubectl exec postgres-0 -n <namespace> -- psql -U openslides -d openslides -c "
DROP SCHEMA IF EXISTS public CASCADE;
DROP SCHEMA IF EXISTS media CASCADE;
DROP SCHEMA IF EXISTS vote CASCADE;
CREATE SCHEMA public;
"

# Restore backup
kubectl exec postgres-0 -n <namespace> -- \
  psql -U openslides -d openslides -f /tmp/backup.sql
```

### Step 5: Run Database Migrations

After restoring an older backup to a newer OpenSlides version, migrations must be finalized.

```bash
# Find backend manage pod
kubectl get pods -n <namespace> | grep backendmanage

# Check migration status
kubectl exec <backendmanage-pod> -n <namespace> -- \
  python openslides_backend/migrations/migrate.py stats
```

Example output:
```
- Registered migrations for migration index 70
- The positions have a migration index of 67
-> Migration/Finalization is needed
```

Finalize migrations:

```bash
kubectl exec <backendmanage-pod> -n <namespace> -- \
  python openslides_backend/migrations/migrate.py finalize
```

Expected output:
```
Finalize migrations.
3 model migrations to apply.
Migrating models from MI 67 to MI 70 ...
Done.
```

### Step 6: Restart Deployments

```bash
kubectl rollout restart deployment -n <namespace>
kubectl rollout status deployment -n <namespace>
```

### Step 7: Verify

1. Check all pods are running: `kubectl get pods -n <namespace>`
2. Access OpenSlides in browser
3. Verify version in Legal Notice
4. Test login with existing users
5. Verify data integrity
6. **Once verified, you can delete the backup file**

## Browser Cache

**Important:** OpenSlides uses aggressive client-side caching (Service Workers). After upgrades, users **must** clear their browser cache.

### How to Clear Browser Cache

**Chrome/Edge/Brave:**
1. Open DevTools: `F12` or `Cmd+Option+I` (Mac)
2. Go to **Application** tab
3. Left sidebar: **Storage** → Click **"Clear site data"** button
4. Hard reload: `Cmd+Shift+R` (Mac) or `Ctrl+Shift+R` (Windows)

**Firefox:**
1. Open DevTools: `F12`
2. Go to **Storage** tab
3. Right-click on domain → **"Delete All"**
4. Hard reload: `Cmd+Shift+R` (Mac) or `Ctrl+F5` (Windows)

**Safari:**
1. Develop menu → Empty Caches
2. Hard reload: `Cmd+Option+R`

**Alternative:** Use Incognito/Private browsing mode to test.

**Important:** Inform all users to clear cache after upgrades to avoid issues.

## Troubleshooting

### Migration Warning Popup

**Symptom:** After restore, popup shows "Missing X migrations to apply"

**Solution:**
```bash
kubectl exec <backendmanage-pod> -n <namespace> -- \
  python openslides_backend/migrations/migrate.py finalize
```

### Old Version Shows in Browser

**Symptom:** Version number doesn't update or old UI appears

**Cause:** Browser cache / Service Worker

**Solution:** Clear browser cache completely (see [Browser Cache](#browser-cache) section)

### Pods in CrashLoopBackOff

**Symptom:** Some pods continuously crash after install

**Possible causes:**
- PostgreSQL not ready yet → Wait for postgres-0 to be Running
- Resource limits too low → Check pod logs and adjust resources
- TLS/Ingress misconfiguration → Check ingress logs

**Debug:**
```bash
# Check pod logs
kubectl logs <pod-name> -n <namespace> --tail=50

# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>
```

### Backup Restore Fails

**Symptom:** Errors during `psql` restore

**Solution:**
1. Ensure schemas are dropped completely (see Step 4)
2. Check backup file integrity: `head backup.sql`
3. Verify PostgreSQL version compatibility

### Migration Fails

**Symptom:** `migrate.py finalize` returns errors

**Solution:**
1. Check logs: `kubectl logs <backendmanage-pod> -n <namespace>`
2. Verify database connectivity
3. Check migration status: `migrate.py stats`
4. If necessary, restore backup again and retry

## Migrating from docker-compose

When migrating from docker-compose to Kubernetes:

```bash
# 1. On docker-compose server, create backup
docker exec <postgres-container> pg_dump -U openslides -d openslides > backup.sql

# 2. Transfer backup to local machine
scp user@server:/path/to/backup.sql .

# 3. Follow normal upgrade process above (Steps 3-7)
```

The chart automatically generates new secrets - no need to manually transfer old secrets.

## Chart Updates (No Version Change)

For chart-only updates (e.g., 1.0.2 → 1.0.3) without OpenSlides version change:

```bash
helm repo update
helm upgrade openslides openslides/openslides-k3s-traefik \
  -n <namespace> \
  -f your-values.yaml
```

No backup/restore needed for chart-only updates.

## Support

- GitHub Issues: https://github.com/jonaskern-dev/openslides-helm/issues
- OpenSlides Documentation: https://openslides.com
