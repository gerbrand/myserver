# My Server

## Introduction
On https://gerbrand.software-creation.nl/ I'm running my own server. To keep things simple, I've decided to use a simple docker compose configuration, rather than using Kubernetes, NixOS, Spack.

Well start with the basics, setting up a certificate. Don't want to expose anything unsecured. [Digitalocean](https://www.digitalocean.com/community/tutorials/how-to-secure-nginx-with-let-s-encrypt-on-ubuntu-20-04) has a nice tutorial

## Setting up nginx and letsencrypt via certbot
I've installed nginx and certbot:
```shell
sudo apt install nginx certbot
sudo certbot --nginx -d gerbrand.software-creation.nl
```
Slightly surprisingly, this works out-of-the box! Nginx configuration is updated, a certificate is made available. So now I have default website running on https://gerbrand.software-creation.nl/.
```
Welcome to nginx!

If you see this page, the nginx web server is successfully installed and working. Further configuration is required.

For online documentation and support please refer to nginx.org.
Commercial support is available at nginx.com.

Thank you for using nginx.
```

## Running application via docker
Now to host an application! The first application I wanted to host is [Etherpad](https://etherpad.org/).

The etherpad website lists a docker-compose configuration to run the application, let's try that. I just started by copy&pasting the etherpad [docker-compose.yml](docker-compose.yml) to my own repository. I'll have to think later if I want to use that as my basic 'infrastructure-as-code'  
On the server I've installed [podman](https://podman.io/). Podman is an open-source alternative to docker we probably all know. The traditional docker command is configured to use dockerhub by default. Which means docker pull myimage will by default pull from dockerhub.com. For podman, you have to set up the registry itself in `/etc/containers`. Might seem a bit cumbersome at first, but making it explicit where you pull software from is a great advantage imho.  
Installation is pretty easy, packages can be installed via [apt on ubuntu](https://podman.io/docs/installation#ubuntu):
```shell
apt install podman
```

So how to get the docker compose file to my server? I don't want to set up any git key on my private server. I'll start with using my own laptop as integration server. Since there is no build, that just means the only 'deploy' needed is copying the content of my git directory to a work dir
```shell
# From my laptop
rsync -av . mytransipserver:work/
# Login to my server
ssh mytransipserver
cd work
# Update DOCKER_COMPOSE_APP_ADMIN_PASSWORD and DOCKER_COMPOSE_APP_USER_PASSWORD with something more secret
vi .env
# Restart
podman compose up -d
```
No unit-tests, integration tests !? I'll set something up like that later, for now I have a simple [deploy.sh](deploy.sh) script.

## Setting up host via nginx

Now to set up the host. 
My server is hosted at [transip](https://www.transip.nl). In the web-console I've updated dns for *.g.software-creation.nl to point to my server as well.

After waiting for a short while for dns to be updated I run again to add the new host:
```shell
sudo certbot --nginx -d gerbrand.software-creation.nl -d etherpad.g.software-creation.nl
```

certbot will update the nginx configuration. Of course by default just the boring website will be displayed, so let's update the configuration

I open default configuration using an editor that should be installed on any machine:
```shell
vi /etc/nginx/sites-enabled/default
```

Somewhere in the file there's a server section that contains the line `server_name etherpad.g.software-creation.nl; # managed by Certbot`
And somewhere below that the following default content is added:
```
       location / {
               # First attempt to serve request as file, then
                       # as directory, then fall back to displaying a 404.
               try_files $uri $uri/ =404;
       }
```
I just replace that whole location block with this:
```
    #Pass to Docker-compose of etherpad
    location / {
               proxy_pass http://localhost:9001;

               proxy_http_version 1.1;
               proxy_set_header Upgrade $http_upgrade;
               proxy_set_header Connection "upgrade";

               proxy_set_header Host $host;
               proxy_set_header X-Real-IP $remote_addr;
               proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
               proxy_set_header X-Forwarded-Proto $scheme;
               proxy_set_header X-Forwarded-Port 443;
       }
```
The above block will result in any traffic under https://etherpad.g.software-creation.nl to be passed on _unencrypted_ to docker application that's exposed to localhost:9001 . Proxy headers are passed in case the application needs to 'know' which hosts it's originally on.  
Container management platforms of Kubernetes use a similar machanism to pass traffic from outside to containers. Of course that's fully automated for you.

Now I save the file (in vi using `:wq`, in case your stuck), and restart nginx:
```shell
service nginx reload
```

and it works! on https://etherpad.g.software-creation.nl etherpad is running and I can do create documents. Next step authentication. I could set up keycloak, or decide to use google. For now, you'll just get a Forbidden. For next time!