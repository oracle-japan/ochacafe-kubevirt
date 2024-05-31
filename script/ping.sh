#!/bin/bash
IP=$(minikube ip)
PORT=$(kubectl get svc testvm-http -o jsonpath='{.spec.ports[0].nodePort}')
while true; do curl ${IP}:${PORT} ;sleep 2s; done