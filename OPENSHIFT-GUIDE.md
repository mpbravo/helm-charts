# OpenShift Deployment Guide

## Quick Start: Deploy SQL Server on OpenShift Web Console

### Step 1: Add Helm Repository to OpenShift

#### Option A: Using Web Console

1. **Navigate to Helm Repositories:**
   - Switch to **Administrator** perspective
   - Go to **Helm** → **Helm Repositories**
   - Click **Create** → **HelmChartRepository**

2. **Paste this configuration:**
   ```yaml
   apiVersion: helm.openshift.io/v1beta1
   kind: HelmChartRepository
   metadata:
     name: mpbravo-charts
   spec:
     connectionConfig:
       url: https://mpbravo.github.io/helm-charts/
     name: SQL Server Charts
     description: Microsoft SQL Server Helm charts for OpenShift
   ```

3. **Click Create**

#### Option B: Using CLI

Apply the provided configuration file:

```bash
oc apply -f openshift-helm-repo.yaml
```

Or run directly:

```bash
oc apply -f - <<EOF
apiVersion: helm.openshift.io/v1beta1
kind: HelmChartRepository
metadata:
  name: mpbravo-charts
spec:
  connectionConfig:
    url: https://mpbravo.github.io/helm-charts/
  name: SQL Server Charts
EOF
```

### Step 2: Deploy from Web Console

1. **Switch to Developer Perspective:**
   - Click **Developer** in the top-left dropdown
   - Select your project/namespace (or create a new one)

2. **Add Helm Chart:**
   - Click **+Add** in the left sidebar
   - Select **Helm Chart** from the catalog
   - Search for **"sql-server"**

3. **Configure Installation:**
   - Click on the **SQL Server** chart
   - Click **Install Helm Chart**

4. **Set Release Name:**
   - Enter a name like: `mssql-production`

5. **Configure Parameters:**

   **In Form View (if available):**
   - The form will show all configurable options grouped by category
   - Fill in required fields (especially SA Password)

   **In YAML View:**
   
   Switch to YAML view and configure these key parameters:

   ```yaml
   # REQUIRED: Set SA Password
   mssql:
     saPassword: "YourStrongP@ssw0rd123!"
     secretName: "mssql"
   
   # SQL Server Edition
   MSSQL_PID:
     value: "Developer"  # Or Express, Standard, Enterprise
   
   # Must accept EULA
   ACCEPT_EULA:
     value: "y"
   
   # Resources
   resources:
     requests:
       memory: "4G"      # Adjust based on your needs
       cpu: "2000m"
     limits:
       memory: "4G"
       cpu: "2000m"
   
   # Storage
   persistence:
     size: "20Gi"        # Adjust based on your needs
   
   # Service Type
   service:
     type: "LoadBalancer"  # Or NodePort, ClusterIP
     port: 1433
   
   # Image version
   image:
     tag: "2022-latest"
   
   # For OpenShift - keep default security context
   podSecurityContext:
     fsGroupChangePolicy: OnRootMismatch
     # DO NOT set fsGroup - OpenShift assigns this automatically
   
   containerSecurityContext:
     capabilities:
       add:
       - NET_BIND_SERVICE
   ```

6. **Install:**
   - Click **Install** button
   - Wait for deployment to complete

### Step 3: Access Your SQL Server

#### Get the External IP/Route

**For LoadBalancer service:**

```bash
oc get service -l app.kubernetes.io/name=sql-server
```

Look for the `EXTERNAL-IP` or `LoadBalancer Ingress`.

**For Route (OpenShift specific):**

If you want to create a route:

```bash
oc expose service mssql-deployment --port=1433
```

#### Connect to SQL Server

**Using sqlcmd:**

```bash
sqlcmd -S <EXTERNAL-IP-OR-ROUTE> -U sa -P 'YourStrongP@ssw0rd123!'
```

**Using Connection String:**

```
Server=<EXTERNAL-IP>,1433;Database=master;User Id=sa;Password=YourStrongP@ssw0rd123!;TrustServerCertificate=true;
```

### Step 4: Verify Deployment

#### Check Pod Status

```bash
oc get pods -l app.kubernetes.io/name=sql-server
```

#### View Logs

```bash
oc logs -f <pod-name>
```

#### Check Persistent Volume

```bash
oc get pvc
```

#### Port Forward (for testing)

```bash
oc port-forward service/mssql-deployment 1433:1433
```

Then connect to `localhost:1433`.

## Common Configuration Scenarios

### Scenario 1: Development Environment

```yaml
MSSQL_PID:
  value: "Developer"
resources:
  requests:
    memory: "2G"
    cpu: "2000m"
persistence:
  size: "8Gi"
service:
  type: "ClusterIP"  # Internal only
```

### Scenario 2: Production Environment

```yaml
MSSQL_PID:
  value: "Enterprise"
resources:
  requests:
    memory: "8G"
    cpu: "4000m"
  limits:
    memory: "8G"
    cpu: "4000m"
persistence:
  size: "200Gi"
service:
  type: "LoadBalancer"
```

### Scenario 3: High Memory Workload

```yaml
MSSQL_PID:
  value: "Standard"
resources:
  requests:
    memory: "16G"
    cpu: "4000m"
  limits:
    memory: "16G"
    cpu: "4000m"
persistence:
  size: "100Gi"
```

## Upgrading Your Deployment

### From Web Console

1. Go to **Helm** in the left sidebar
2. Find your release
3. Click the three dots menu → **Upgrade**
4. Modify values as needed
5. Click **Upgrade**

### From CLI

```bash
helm upgrade mssql-production mpbravo/sql-server \
  --set mssql.saPassword='YourStrongP@ssw0rd123!' \
  --set persistence.size=50Gi
```

## Uninstalling

### From Web Console

1. Go to **Helm** in the left sidebar
2. Find your release
3. Click the three dots menu → **Uninstall Helm Release**
4. Confirm deletion

### From CLI

```bash
helm uninstall mssql-production
```

**Note:** This preserves the PVC. To delete data:

```bash
oc delete pvc data-mssql-production-sql-server-0
```

## Troubleshooting

### Pod Won't Start

Check pod events:
```bash
oc describe pod <pod-name>
```

Check logs:
```bash
oc logs <pod-name>
```

### Password Issues

Ensure password meets requirements:
- At least 8 characters
- Contains uppercase, lowercase, numbers, and symbols

### Storage Issues

Check if PVC is bound:
```bash
oc get pvc
```

Check storage class:
```bash
oc get storageclass
```

### Connection Issues

Verify service:
```bash
oc get svc mssql-deployment
```

Test with port-forward:
```bash
oc port-forward service/mssql-deployment 1433:1433
```

## Additional Resources

- [SQL Server on Linux Documentation](https://learn.microsoft.com/en-us/sql/linux/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Helm Documentation](https://helm.sh/docs/)
