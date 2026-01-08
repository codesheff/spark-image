# Project Plan: Spark-Image Docker Build

## Overview
This project aims to build a Docker image for Apache Livy and Apache Spark to be used in a Kubernetes cluster.

## Phase 1: Foundation & Setup ✅ COMPLETED
- [x] Create directory structure (Dockerfile, docker-compose.yml, scripts/, config/, etc.)
- [x] Set up base Dockerfile with appropriate Spark and Livy versions
- [x] Define build arguments and environment variables
- [x] Create .dockerignore file

## Phase 2: Core Docker Image ✅ COMPLETED
- [x] Install Java/JDK as base runtime (Eclipse Temurin 11 JDK)
- [x] Install Apache Spark (3.3.2) and configure it properly
- [x] Install Apache Livy (0.7.1) and integrate with Spark
- [x] Configure necessary ports (8998 for Livy, 7077 for Spark, 6066 for Web UI, 8081 for Worker)
- [x] Set up user permissions and security best practices (non-root spark user)
- [x] Test Docker build and image functionality
- [x] Test docker-compose deployment (verified healthy status and working API)

## Phase 3: Kubernetes-Native Spark Execution ⧖ IN PROGRESS
- [ ] Configure Livy and Spark for Kubernetes scheduler backend
- [ ] Set up Kubernetes API server connectivity from Livy
- [ ] Configure RBAC and ServiceAccount for pod creation
- [ ] Add Spark driver and executor pod templates
- [ ] Create ConfigMaps for K8s-specific Spark configurations
- [ ] Update Kubernetes manifests to enable pod creation
- [ ] Add documentation on K8s backend configuration
- [ ] Test Livy job submission that creates new executor pods
- [ ] Create example job submission scripts for K8s

## Phase 4: Kubernetes Integration (Standard)
- [ ] Create Kubernetes manifests (Deployment, Service, ConfigMap)
- [ ] Configure resource requests/limits
- [ ] Set up health checks (liveness/readiness probes)
- [ ] Document volume mount requirements

## Phase 5: Configuration & Scripts
- [ ] Create entrypoint script for container initialization
- [ ] Build configuration templates for Spark and Livy
- [ ] Add helper scripts for common operations
- [ ] Document environment variable configuration

## Phase 6: Testing & Documentation
- [ ] Create test cases for image building and functionality
- [ ] Write comprehensive README with build/deployment instructions
- [ ] Document supported configurations and customization
- [ ] Add CI/CD pipeline (GitHub Actions) for automated builds
- [ ] Create troubleshooting guide

## Phase 7: Optimization & Release
- [ ] Multi-stage Docker build to minimize image size
- [ ] Security scanning and vulnerability checks
- [ ] Performance tuning documentation
- [ ] Create version tagging and release process
