# SQL Server Helm Chart

A Helm chart for deploying Microsoft SQL Server on Kubernetes and OpenShift clusters with persistent storage and high availability.

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

## Prerequisites

- Kubernetes 1.19+ or OpenShift 4.x
- Helm 3.0+
- Persistent Volume provisioner support in the cluster
- At least 2GB RAM and 2 CPU cores available

### Platform Requirements

**Red Hat OpenShift:**
- OpenShift CLI (`oc`) installed
- Authenticated to your OpenShift cluster
- A default Storage Class assigned

## Installation

Check installation details on sql-server chart README file.