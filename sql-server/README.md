# SQL Server Helm Chart

A Helm chart for deploying Microsoft SQL Server on OpenShift with persistent storage and high availability.

## Overview

This Helm chart is based on the official Microsoft documentation for deploying SQL Server container clusters:
- [Quickstart: Deploy a SQL Server Container Cluster on Azure Kubernetes Services or Red Hat OpenShift](https://learn.microsoft.com/en-gb/sql/linux/quickstart-sql-server-containers-azure?view=sql-server-ver17&tabs=oc)

The chart provides:
- SQL Server 2022 container deployment
- Persistent storage with automatic volume provisioning
- Configurable resource requests and limits
- Security context configuration for both Kubernetes and OpenShift
- LoadBalancer service for external connectivity
- Automatic pod recovery and high availability


## Installation

### Basic Installation

Install the chart with a release name `mssql-server`:

```bash
helm install mssql-server ./sql-server \
  --set mssql.saPassword='YourStrongP@ssw0rd'
```

**Important:** The SA password must meet SQL Server password policy requirements:
- Minimum 8 characters long
- Contains characters from three of the following four sets:
  - Uppercase letters (A-Z)
  - Lowercase letters (a-z)
  - Base-10 digits (0-9)
  - Symbols (!, @, #, $, %, etc.)
- Passwords can be up to 128 characters long


## Configuration

The following table lists the configurable parameters of the SQL Server chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicas` | Number of SQL Server replicas | `1` |
| `image.repository` | SQL Server container image repository | `mcr.microsoft.com/mssql/server` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `image.tag` | SQL Server version tag | `2022-latest` |
| `ACCEPT_EULA.value` | Accept SQL Server EULA (required) | `y` |
| `MSSQL_PID.value` | SQL Server edition (Developer, Express, Standard, Enterprise) | `Developer` |
| `MSSQL_AGENT_ENABLED.value` | Enable SQL Server Agent | `false` |
| `mssql.saPassword` | SA password (REQUIRED during installation) | `""` |
| `mssql.secretName` | Name of the Kubernetes secret | `mssql` |
| `hostname` | Hostname for the SQL Server instance | `mssqlinst` |
| `containers.ports.containerPort` | SQL Server port | `1433` |
| `service.type` | Kubernetes service type | `LoadBalancer` |
| `service.port` | Service port | `1433` |
| `persistence.size` | Persistent volume size | `8Gi` |
| `persistence.accessModes` | Persistent volume access modes | `[ReadWriteOnce]` |
| `resources.requests.memory` | Memory request | `2G` |
| `resources.requests.cpu` | CPU request | `2000m` |
| `resources.limits.memory` | Memory limit | `2G` |
| `resources.limits.cpu` | CPU limit | `2000m` |
| `podSecurityContext.fsGroupChangePolicy` | File system group change policy | `OnRootMismatch` |
| `containerSecurityContext.capabilities.add` | Container capabilities to add | `[NET_BIND_SERVICE]` |
| `terminationGracePeriodSeconds` | Pod termination grace period | `30` |


## Usage

### Getting the SQL Server External IP

After installation, get the external IP address:

```bash
# For OpenShift
oc get service mssql-deployment
```

Wait for the `EXTERNAL-IP` to be assigned (may take a few minutes).

### Connecting to SQL Server

#### Using sqlcmd

```bash
sqlcmd -S <EXTERNAL-IP> -U sa -P 'YourStrongP@ssw0rd'
```

#### Using Connection String

```
Server=<EXTERNAL-IP>,1433;Database=master;User Id=sa;Password=YourStrongP@ssw0rd;TrustServerCertificate=true;
```

#### Compatible Tools

- SQL Server Management Studio (SSMS)
- Azure Data Studio
- Visual Studio Code with MSSQL extension
- SQL Server Data Tools (SSDT)
- Any SQL Server client application

### Verifying the Deployment

Check pod status:

```bash
# OpenShift
oc get pods
```

View pod logs:

```bash
# OpenShift
oc logs <pod-name>
```

Check persistent volume claim:

```bash
# OpenShift
oc get pvc
```

## High Availability and Recovery

The chart is configured for automatic recovery:

1. If the SQL Server pod fails, Kubernetes/OpenShift automatically recreates it
2. The persistent volume ensures data survives pod restarts
3. The LoadBalancer service maintains the same IP address after recovery

To test recovery, you can delete the pod:

```bash
# OpenShift
oc delete pod <pod-name>
```

The cluster will automatically create a new pod and reconnect it to the persistent storage.

## Security Considerations

⚠️ **Important Security Notes:**

1. **Never commit passwords to version control**
   - Always use `--set` or environment variables for passwords
   - Consider using Kubernetes secrets or external secret management solutions

2. **Production deployments:**
   - Use `Enterprise` or `Standard` edition (not `Developer`)
   - Configure appropriate resource limits
   - Implement network policies
   - Use TLS/SSL certificates
   - Restrict service access with firewall rules

3. **Non-root containers:**
   - This chart runs SQL Server as a non-root user (mssql)
   - Appropriate security contexts are configured

## Upgrading

To upgrade the release:

```bash
helm upgrade mssql-server ./sql-server \
  --set mssql.saPassword='YourStrongP@ssw0rd' \
  -f custom-values.yaml
```

## Uninstalling

To uninstall/delete the `mssql-server` deployment:

```bash
helm uninstall mssql-server
```

**Note:** This command removes all resources associated with the chart, **except** the Persistent Volume Claim (PVC). To delete the PVC and data:

```bash
# OpenShift
oc delete pvc data-mssql-server-0
```

## Troubleshooting

### Pod stays in Pending state

Check if the persistent volume is bound:

```bash
oc describe pvc
```

Ensure your cluster has a storage provisioner configured.

### Cannot connect to SQL Server

1. Verify the service has an external IP:
   ```bash
   oc get service mssql-deployment
   ```

2. Check if the pod is running:
   ```bash
   oc get pods
   ```

3. View pod logs for errors:
   ```bash
   oc logs <pod-name>
   ```

### Password not accepted

Ensure your password meets SQL Server requirements (see Installation section).

### Out of memory errors

Increase the memory limits in your values file:

```yaml
resources:
  requests:
    memory: "4G"
  limits:
    memory: "4G"
```

## License Considerations

- **Developer Edition:** Free for development and testing, not licensed for production
- **Express Edition:** Free, limited to 1GB RAM and 10GB database size
- **Standard/Enterprise Editions:** Require appropriate licensing for production use

For more information, see [SQL Server Licensing](https://www.microsoft.com/sql-server/sql-server-2022-pricing).

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## References

- [Microsoft SQL Server on Linux Documentation](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-overview)
- [SQL Server Container Images](https://hub.docker.com/_/microsoft-mssql-server)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [OpenShift Documentation](https://docs.openshift.com/)
- [Helm Documentation](https://helm.sh/docs/)

## Support

For issues related to:
- **This Helm chart:** Open an issue in this repository
- **SQL Server:** See [Microsoft SQL Server Documentation](https://learn.microsoft.com/en-us/sql/)
- **OpenShift:** Consult respective platform documentation
