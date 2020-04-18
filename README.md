## Start

```bash
bundle && yarn && rails hot
```

## Deploy

### Build docker image

from local
```bash
docker build --build-arg rails_env=production -t $DOCKER_ACC/$DOCKER_REPO:$IMG_TAG .
```

from remote (you have to pass the master_key as an build-arg)
```bash
docker build --build-arg rails_env=production --build-arg master_key=$MASTER_KEY -t $DOCKER_ACC/$DOCKER_REPO:$IMG_TAG .
```

[push to docker hub](http://blog.shippable.com/build-a-docker-image-and-push-it-to-docker-hub) (after login)
```bash
docker push $DOCKER_ACC/$DOCKER_REPO:$IMG_TAG
```

build & push image using [lib/tasks/deploy.rake](lib/tasks/deploy.rake)

```bash
rails deploy:production:push
```

### Set credentials

open credential and paste db, redis urls

```bash
EDITOR="nano" rails credentials:edit

# like this
production:
  database_url: DATABASE_URL
  redis_url: REDIS_URL
```

### Docker

Serve your application image from any image [hosting service](https://hub.docker.com/).

```bash
docker build --build-arg rails_env=production .
```

### Kubernetes

[k8s/README.md](k8s/README.md)

## Tuning

### Puma

`process * thread * pod replicas < db connection`

[heroku blog](https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#process-count-value)

### Application Nginx

[read](https://www.digitalocean.com/community/tutorials/how-to-optimize-nginx-configuration)

You can customize application nginx through [config-map](k8s/project/rails-template-stimulus-nginx-conf.yaml) as usual.

### Ingress Nginx

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