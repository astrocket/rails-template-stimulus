## Prepare Kubernetes Cluster

### Create New Kubernetes cluster from DigitalOcean

https://cloud.digitalocean.com/kubernetes

### Install Kubectl

The Kubernetes command-line tool, kubectl, allows you to run commands against Kubernetes clusters. ([link](https://kubernetes.io/docs/tasks/tools/install-kubectl/))
```bash
brew install kubectl
# kubectl version
```

### Connect your cluster

Use the name of your cluster instead of example-cluster-01 in the following command.

Generate API Token & Paste it ([link](https://cloud.digitalocean.com/account/api/tokens))
```bash
DigitalOcean access token: your_DO_token
```

Authenticate through doctl command (doctl is a DigitalOcean's own cli tool [link](https://github.com/digitalocean/doctl))
```bash
brew install doctl
doctl auth init
# paste your_DO_token
```

Add your cluster to local config (you can get your cluster's name from DO's dashboard)
```bash
doctl kubernetes cluster kubeconfig save example-cluster-01
# kubectl config current-context
```

## Cluster set up

Following document is a summary of digital ocean's [official doc](https://www.digitalocean.com/community/tutorials/how-to-set-up-an-nginx-ingress-with-cert-manager-on-digitalocean-kubernetes).
+ I modified LoadBalancer part to fix the issue from generating Let's Encrypt certification.
+ upgraded resource versions
+ fixed some [cert-manager issue](https://github.com/jetstack/cert-manager/issues/2759)

### Install mandatory resources
```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
```

### Install load balancer service

This step, kubernetes will automatically ask digital ocean's LoadBalancer.
If you don't have any LoadBalancer unit, it will automatically create one. (also start charging you)

> k8s/cluster/load_balancer.yaml
```yaml
kind: Service
apiVersion: v1
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  externalTrafficPolicy: Cluster
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  ports:
    - name: http
      port: 80
      protocol: TCP
      targetPort: http
    - name: https
      port: 443
      protocol: TCP
      targetPort: https
```

```bash
kubectl apply -f k8s/cluster/load_balancer.yaml
```

### Confirm that the Ingress Controller Pods have started
```bash
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx
```

### Confirm that the DigitalOcean Load Balancer was successfully created
```bash
kubectl get svc --namespace=ingress-nginx
```

### Install Cert-Manager
Certificates can be requested and configured by annotating Ingress Resources with the cert-manager.io/issuer annotation, appending a tls section to the Ingress spec, and configuring one or more Issuers or ClusterIssuers to specify your preferred certificate authority.

```bash
# install cert-manager and its Custom Resource Definitions (CRDs) like Issuers and ClusterIssuers.
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.14.1/cert-manager.yaml

# Verify installation
kubectl get pods --namespace cert-manager
```

### Create SSL Issuer

You only need one Issuer per cluster. You can reuse for other projects.

> k8s/cluster/lets_encrypt_issuer.yaml

```yaml
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
  namespace: cert-manager
spec:
  acme:
    # The ACME server URL
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME registration
    email: admin@example.com
    # Name of a secret used to store the ACME account private key
    privateKeySecretRef:
      name: letsencrypt-prod
    # Enable the HTTP-01 challenge provider
    solvers:
    - http01:
        ingress:
          class: nginx
```

```bash
kubectl create -f k8s/cluster/lets_encrypt_issuer.yaml
``` 

## Deploy

### Deploying Demo App

[read](https://webcloudpower.com/helm-rails-static-files-path/)

Create Demo Ingress, Service, Pod. (to test configuration)

```bash
kubectl apply -f k8s/demo.yaml
```

Logging deployed demo app

```bash
rails deploy:logs:demo
```

Check Let's Encrypt progress

```bash
kubectl describe certificate rails-template-stimulus-demo-tls

# Below is an example success message
Events:
  Type    Reason        Age   From          Message
  ----    ------        ----  ----          -------
  Normal  GeneratedKey  5m   cert-manager  Generated a new private key
  Normal  Requested     5m   cert-manager  Created new CertificateRequest resource "rails-template-stimulus-demo-tls-1514794236"
  Normal  Issued        5m   cert-manager  Certificate issued successfully
```

Problem with SSL? => debug cert-manager [read](https://cert-manager.io/docs/faq/acme/).

To delete all demo resources

```bash
kubectl delete -f k8s/demo.yaml
```

### Deploying Production App

It's recommended to manage resources seperately to prevent downtime while updating your app.

* `k8s/project/rails-template-stimulus-nginx-conf.yaml` creates application level nginx's(* is different from ingress-nginx*) config-map, where we serve static files, redirect app traffic to puma. (It will be used when deploying k8s/app.yaml)

```bash
kubectl create secret generic rails-template-stimulus-secrets --from-file=rails-template-stimulus-master-key=config/master.key # push master.key to k8s secret
kubectl apply -f k8s/ingress.yaml # from load-balancer to web service
kubectl apply -f k8s/service.yaml # web service for web deployment
kubectl apply -f k8s/project/rails-template-stimulus-nginx-conf.yaml # for web deployment's nginx
kubectl apply -f k8s/web.yaml # puma & nginx
kubectl apply -f k8s/sidekiq.yaml # sidekiq
... etc
```

## Extra

### Monitoring Commands

#### Pod

```bash
kubectl get pods
# NAME                                 READY   STATUS    RESTARTS   AGE
# rails-template-stimulus-demo-web-f45fbdf9-7wsqn   2/2     Running   0          18s
# rails-template-stimulus-demo-web-f45fbdf9-fsxz8   2/2     Running   0          18s
# rails-template-stimulus-demo-web-f45fbdf9-qhms6   2/2     Running   0          18s
# rails-template-stimulus-demo-web-f45fbdf9-vqfmj   2/2     Running   0          18s

# for single pod (tail 5 lines)
kubectl logs -f --tail=5 rails-template-stimulus-demo-web-f45fbdf9-7wsqn -c app
kubectl logs -f --tail=5 rails-template-stimulus-demo-web-f45fbdf9-7wsqn -c nginx

# for all pods
kubectl logs -f --tail=5 --selector app=rails-template-stimulus-demo-web -c app
kubectl logs -f --tail=5 --selector app=rails-template-stimulus-demo-web -c nginx
```

#### Container

log containers using [lib/tasks/deploy.rake](lib/tasks/deploy.rake)

```bash
rails deploy:logs:web
rails deploy:logs:sidekiq
```

### Deployment Script

Execute multiple kubectl commands with rails task.

```bash
# apply demo service, ingress, config, deployments
rails deploy:demo:up
rails deploy:demo:down # rollback

# push master.key to kubernetes secret
rails deploy:production:set_master_key

# apply production application nginx config
# apply production ingress
rails deploy:production:ingress:up
rails deploy:production:ingress:down # rollback and delete master_key

# migrate database with production image
rails deploy:production:migrate

# apply production deployments
rails deploy:production:all
```

### Managing Secrets

[How to Read Kubernetes Secrets](https://howchoo.com/g/ywvlmgnmode/read-kubernetes-secrets)

push master.key to cluster secrets from local file

```bash
kubectl create secret generic rails-template-stimulus-secrets --from-file=rails-template-stimulus-master-key=config/master.key
```

reference pushed key from pod

```yaml
...
          env:
          - name: RAILS_MASTER_KEY
            valueFrom:
              secretKeyRef:
                name: rails-template-stimulus-secrets
                key: rails-template-stimulus-master-key
...
```

read decoded key

```yaml
kubectl get secret rails-template-stimulus-secrets -o jsonpath="{.data.rails-template-stimulus-master-key}" | base64 --decode
```

delete secrets

```bash
kb delete secret rails-template-stimulus-secrets
```

### Tuning

#### Puma

`process * thread * pod replicas < db connection`

[heroku blog](https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#process-count-value)

#### Application Nginx

[read](https://www.digitalocean.com/community/tutorials/how-to-optimize-nginx-configuration)

You can customize application nginx through [config-map](k8s/project/rails-template-stimulus-nginx-conf.yaml) as usual.

#### Ingress Nginx

To make your service scalable, you should consider tuning your [ingress-nginx](https://kubernetes.github.io/ingress-nginx) as your needs.

As you can read out from the guide linked above, you have 3 ways to tune ingress-nginx.

**ConfigMap** : Global options for every ingress (like worker_process, worker_connection, proxy-body-size ..)

**Annotation** : Per ingress options (like ssl, proxy-body-size..)

**Custom Template** : Using file

If you configure the same option using Annotation and ConfigMap, Annotation will override ConfigMap. (ex. proxy-body-size)

https://github.com/nginxinc/kubernetes-ingress/tree/master/examples

> example of scalable websocket server architecture
[read](https://github.com/nginxinc/kubernetes-ingress/tree/master/examples/websocket)
```text
ws.example.com ->
LoadBalancer ->
Websocket supportive Nginx Ingress with SSL (with enough worker_connections) ->
Anycable Go server ->
Anycable RPC rails server
```