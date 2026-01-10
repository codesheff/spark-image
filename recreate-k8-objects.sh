#!/usr/bin/env bash
kubectl delete -f k8s/spark-livy-manifest.yaml
kubectl apply -f k8s/spark-livy-manifest.yaml