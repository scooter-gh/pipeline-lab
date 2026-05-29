# Kubectl Operations Runbook

This runbook covers manual kubectl operations against the k3d cluster for learning and debugging. All commands assume a cluster is running and kubectl has been configured.

## Prerequisites

The k3d cluster must be running. If not, create one:

```bash
make k8s-up
```

This creates the cluster and configures kubectl access automatically.

## 1. Cluster Inspection

### Verify cluster nodes

```bash
make k8s-status
```

**Expected output:**
```
NAME                        STATUS   ROLES                  AGE   VERSION
k3d-pipeline-lab-agent-0    Ready    <none>                 2m    v1.31.5+k3s1
k3d-pipeline-lab-server-0   Ready    control-plane,master   2m    v1.31.5+k3s1
```

### View all namespaces

```bash
kubectl get namespaces
```

**Expected output:**
```
NAME              STATUS   AGE
default           Active   2m
kube-node-lease   Active   2m
kube-public       Active   2m
kube-system       Active   2m
vote-app          Active   30s
```

## 2. Working with the vote-app Namespace

### View all resources in the namespace

```bash
kubectl get all -n vote-app
```

**Expected output:**
```
NAME                                   READY   STATUS    RESTARTS   AGE
pod/vote-app-redis-7b9b7bf968-9lhmf    1/1     Running   0          30s
pod/vote-app-results-754b47bdf-d56dv 1/1     Running   0          30s
pod/vote-app-votes-766bc5889-ps6vv     1/1     Running   0          30s

NAME                       TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
service/redis              ClusterIP   10.43.78.91    <none>        6379/TCP
service/vote-app-results   ClusterIP   10.43.241.91   <none>        8081/TCP
service/vote-app-votes     ClusterIP   10.43.182.47   <none>        8080/TCP

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/vote-app-redis     1/1     1            1           30s
deployment.apps/vote-app-results   1/1     1            1           30s
deployment.apps/vote-app-votes     1/1     1            1           30s
```

## 3. Pod Operations

### Describe a specific pod

```bash
kubectl describe pod -n vote-app -l app.kubernetes.io/component=votes
```

This shows the full pod spec, events, container state, probes, and environment variables.

### View pod logs

```bash
# Votes service logs
kubectl logs -n vote-app -l app.kubernetes.io/component=votes --tail=20

# Results service logs
kubectl logs -n vote-app -l app.kubernetes.io/component=results --tail=20

# Redis logs
kubectl logs -n vote-app -l app.kubernetes.io/component=redis --tail=20
```

### Follow logs in real-time

```bash
kubectl logs -n vote-app -l app.kubernetes.io/component=votes -f
```

### Execute commands inside a pod

```bash
# Open a shell in the votes pod
kubectl exec -n vote-app -it deploy/vote-app-votes -- sh

# Inside the pod, you can:
ls -la /app
cat /app/main.py

# Test Redis connectivity
python3 -c "import redis; r = redis.Redis(host='redis'); print(r.ping())"

# Exit the pod shell
exit
```

## 4. Service Discovery

### View services

```bash
kubectl get services -n vote-app
```

**Expected output:**
```
NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)
redis              ClusterIP   10.43.78.91    <none>        6379/TCP
vote-app-results   ClusterIP   10.43.241.91   <none>        8081/TCP
vote-app-votes     ClusterIP   10.80.182.47   <none>        8080/TCP
```

### Test service DNS resolution from within a pod

```bash
kubectl exec -n vote-app -it deploy/vote-app-votes -- sh

# Inside the pod:
python3 -c "import urllib.request; print(urllib.request.urlopen('http://vote-app-results:8081/results').read())"

exit
```

## 5. Port-Forwarding for Local Access

Port-forwarding lets you access cluster services from your host machine without exposing them via Ingress.

### Forward votes service to localhost:8080

```bash
kubectl port-forward -n vote-app svc/vote-app-votes 8080:8080 &
PF1=$!
```

### Forward results service to localhost:8081

```bash
kubectl port-forward -n vote-app svc/vote-app-results 8081:8081 &
PF2=$!
```

### Test the services locally

```bash
# Cast a vote
curl -X POST http://localhost:8080/vote -H 'Content-Type: application/json' -d '{"option":"a"}'

# Check results
curl http://localhost:8081/results

# Cast another vote
curl -X POST http://localhost:8080/vote -H 'Content-Type: application/json' -d '{"option":"b"}'

# Check updated results
curl http://localhost:8081/results
```

### Clean up port-forwards

```bash
kill $PF1 $PF2
```

## 6. Scaling Deployments

### Scale votes to 3 replicas

```bash
kubectl scale deployment vote-app-votes -n vote-app --replicas=3
```

### Verify scaling

```bash
kubectl get pods -n vote-app -l app.kubernetes.io/component=votes
```

**Expected output:**
```
NAME                             READY   STATUS    RESTARTS   AGE
vote-app-votes-766bc5889-mzcrc   1/1     Running   0          10s
vote-app-votes-766bc5889-ps6vv   1/1     Running   0          2m
vote-app-votes-766bc5889-zlxw2   1/1     Running   0          10s
```

### Scale back to 1

```bash
kubectl scale deployment vote-app-votes -n vote-app --replicas=1
```

## 7. Health Probes

### View probe configuration

```bash
kubectl get deployment vote-app-votes -n vote-app -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'
kubectl get deployment vote-app-votes -n vote-app -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'
```

### Manually test probes

```bash
# From within the pod
kubectl exec -n vote-app -it deploy/vote-app-votes -- sh

# Test health endpoint
wget -qO- http://localhost:8080/health

# Test readiness endpoint
wget -qO- http://localhost:8080/ready

exit
```

## 8. Ingress

### View ingress rules

```bash
kubectl get ingress -n vote-app
```

**Expected output:**
```
NAME       CLASS     HOSTS   ADDRESS                 PORTS   AGE
vote-app   traefik   *       172.19.0.7,172.19.0.8   80      2m
```

### View ingress details

```bash
kubectl describe ingress vote-app -n vote-app
```

### Test ingress (from a pod, since ingress is on port 80 inside the cluster network)

```bash
kubectl run -n vote-app --rm -it debug --image=busybox --restart=Never -- wget -qO- http://vote-app/vote
```

## 9. Pod Disruption Budgets

### View PDBs

```bash
kubectl get pdb -n vote-app
```

**Expected output:**
```
NAME               MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
vote-app-results   1               N/A               0                     2m
vote-app-votes     1               N/A               0                     2m
```

### Understand PDB impact

The PDB ensures at least 1 replica of votes and results is always available during disruptions (node drains, voluntary evictions). Try deleting a pod and watch it be recreated immediately:

```bash
kubectl delete pod -n vote-app -l app.kubernetes.io/component=votes --wait=false
kubectl get pods -n vote-app -l app.kubernetes.io/component=votes -w
```

Press `Ctrl+C` to stop watching.

## 10. Helm Operations

### View deployed releases

```bash
helm list -n vote-app
```

### View release history

```bash
helm history vote-app -n vote-app
```

### View rendered manifests

```bash
helm get manifest vote-app -n vote-app
```

### View release values

```bash
helm get values vote-app -n vote-app
```

### Upgrade with new values

```bash
helm upgrade vote-app ./charts/vote-app -n vote-app --set votes.replicas=2 --set results.replicas=2
```

### Rollback to previous revision

```bash
helm rollback vote-app 1 -n vote-app
```

## 11. Debugging Commands

### View all events in the namespace

```bash
kubectl get events -n vote-app --sort-by='.lastTimestamp'
```

### Describe a deployment for troubleshooting

```bash
kubectl describe deployment vote-app-votes -n vote-app
```

### Check resource usage (if metrics-server were installed)

```bash
kubectl top pods -n vote-app
```

### Check pod resource requests/limits

```bash
kubectl get pod -n vote-app -l app.kubernetes.io/component=votes -o jsonpath='{.items[0].spec.containers[0].resources}'
```

## 12. Cleanup

### Delete the Helm release

```bash
helm uninstall vote-app -n vote-app
```

### Delete the namespace (removes everything)

```bash
kubectl delete namespace vote-app
```

### Delete the entire cluster

```bash
make k8s-down
```

---

## Quick Reference: Common kubectl Patterns

| Task | Command |
|------|---------|
| List pods | `kubectl get pods -n vote-app` |
| List pods with wide output | `kubectl get pods -n vote-app -o wide` |
| List pods with labels | `kubectl get pods -n vote-app --show-labels` |
| Watch pods | `kubectl get pods -n vote-app -w` |
| Get pod YAML | `kubectl get pod -n vote-app POD_NAME -o yaml` |
| Get pod JSON | `kubectl get pod -n vote-app POD_NAME -o json` |
| Delete a pod | `kubectl delete pod -n vote-app POD_NAME` |
| Get deployment YAML | `kubectl get deployment vote-app-votes -n vote-app -o yaml` |
| Edit a deployment | `kubectl edit deployment vote-app-votes -n vote-app` |
| Get service endpoints | `kubectl get endpoints -n vote-app` |
| Run a one-off command | `kubectl run -n vote-app --rm -it debug --image=busybox --restart=Never -- sh` |
| Copy file from pod | `kubectl cp -n vote-app vote-app-votes-xxx:/app/main.py ./main.py` |
| Copy file to pod | `kubectl cp -n vote-app ./main.py vote-app-votes-xxx:/app/main.py` |

## Interactive Shell Access

For the most convenient kubectl access, drop into the runner container with kubeconfig already set:

```bash
make k8s-cli
```

This opens a bash shell where `kubectl`, `helm`, and all cluster commands work directly.
