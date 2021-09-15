---
title: "CI/CD [WOTW-10]"
date: 2021-09-14
author: Tomas Dedic
description: "Desc"
lead: "workshop"
categories:
  - "wotw"
toc: true
autonumbering: true
---
**V dnešním dílu našeho oblíbeného seriálu se podíváme na CI/CD ve vazbě na Kubernetes. Takovou pipeline si ukážeme a trochu vysvětlíme**  
Takže co vlastně budeme stavět, postavíme si aplikaci na které běží tenhle blog.

## KROKY františka kopečka
- aplikace využívá **Framework pro generování stránek ze statického obsahu reprezentovaný markdown dokumenty** [HUGO - The world’s fastest framework for building websites](https://gohugo.io)
- **stránky poběží na NGINX HTTP serveru tzn po změně obsahu stránek, tedy comit v gitu, proběhne build containeru s novým obsahem a jeho push do CR**
- **bude notifikováno repository obsahující manifesty pro Kubernetes a příslušné manifesty budou upraveny tak aby reflektovali nový název kontejneru**
- **nové manifesty budou nasazeny do kubernetes (tzn proběhne nasazení aplikace)**


## CONTINUOUS INTEGRATION
Jako CI tedy bude brána část buildovací a upravení manifestů pro Kubernetes. Použijeme GITHUB jako GIT provider a Github má jako CI nástroj přímo integrován GITHUB ACTIONS tak použijeme ten. Jako CI nástroj lze samozřejmě použít i jiný TOOL, jen je asi vhodné ho nějak svázat s GIT providerem tak aby onen jeden byl notifikován při změně gitu.  
Takže **GITHUB actions**:  
v repozitáři se zdrojovými kódy nadefinujeme samotnou ACTION ve formátu YAML
```yaml
cat .github/workflows/hugo_generate_site.yaml

name: generate_hugo_siteenv

on:
  push:
    branches:
      - master
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-18.04
    env: 
      gitops_repo: gitops_repo
    steps:
      - name: Prepare
        id: prep
        run: |
          DOCKER_IMAGE=ghcr.io/tomasdedic/ocpdoc/hugogen
          VERSION=noop
          if [[ $GITHUB_REF == refs/tags/* ]]; then
            VERSION=${GITHUB_REF#refs/tags/}
          elif [[ $GITHUB_REF == refs/heads/* ]]; then
            VERSION=$(echo ${GITHUB_REF#refs/heads/} | sed -r 's#/+#-#g')
            if [ "${{ github.event.repository.default_branch }}" = "$VERSION" ]; then
              VERSION=edge
            fi
          elif [[ $GITHUB_REF == refs/pull/* ]]; then
            VERSION=pr-${{ github.event.number }}
          fi
          TAGS="${DOCKER_IMAGE}:${VERSION}"
          if [[ $VERSION =~ ^v[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            MINOR=${VERSION%.*}
            MAJOR=${MINOR%.*}
            TAGS="$TAGS,${DOCKER_IMAGE}:${MINOR},${DOCKER_IMAGE}:${MAJOR},${DOCKER_IMAGE}:latest"
          elif [ "${{ github.event_name }}" = "push" ]; then
            TAGS="${DOCKER_IMAGE}:sha-${GITHUB_SHA::8}"
            das
          fi
          echo ::set-output name=version::${VERSION}
          echo ::set-output name=tags::${TAGS}
          echo ::set-output name=created::$(date -u +'%Y-%m-%dT%H:%M:%SZ')
          echo $VERSION
          echo $TAGS
      - name: Checkout repo
        uses: actions/checkout@v2
        with:
          ssh-key: ${{ secrets.ACTIONS_DEPLOY_KEY }}
          submodules: true
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v1
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1
      - name: Login to Registry
        uses: docker/login-action@v1
        with:
          registry: ghcr.io
          # registry: docker.pkg.github.com
          username: dedtom@gmail.com
          password: ${{ secrets.PERSONAL_TOKEN }}
      - id: get-id
        run: |
          id=$(echo ${GITHUB_SHA} | cut -c 1-4)
          echo ${GITHUB_SHA}
          echo $id
          echo "::set-output name=sha::$id"
      - name: Build and publish image to Github
        id: build_and_publish
        uses: docker/build-push-action@v2
        with:
          push: true
          context: .
          file: ./Dockerfile
          tags: ${{steps.prep.outputs.tags}}
          labels: |
            org.opencontainers.image.created=${{ steps.prep.outputs.created }}
            org.opencontainers.image.source=${{ github.repositoryUrl }}
            org.opencontainers.image.version=${{ steps.prep.outputs.version }}
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.licenses=${{ github.event.repository.license.name }}
      - name: Inform ARGO repo that build is success
        if: ${{ steps.build_and_publish.conclusion == 'success' }}
        uses: actions/checkout@v2
        with:
          repository: tomasdedic/ocpdocCD
          token: ${{ secrets.PERSONAL_TOKEN }} # `GitHub_PAT` is a secret that contains your PAT
          path: ${{ env.gitops_repo }}

      - name: Change field image in deployment
        uses: tomasdedic/yq-action@1.4
        with:
          command: yq e '.spec.template.spec.containers.[0].image="${{env.image_tag}}"' -i ${{env.gitops_repo}}/deploy_aks/deployment.yaml && yq e '.spec.template.spec.containers.[0].image="${{env.image_tag}}"' -i ${{env.gitops_repo}}/deploy/deployment.yaml && yq e '.spec.template.spec.containers.[0].image="${{env.image_tag}}"' -i ${{env.gitops_repo}}/deploy_proxy/apps_v1_deployment_proxy.yaml
        env:
          image_tag: ${{ steps.prep.outputs.tags }}
      - name: Commit changes to ARGO repo
        run: |
          cd ${{ env.gitops_repo }}
          git config user.name github-actions
          git config user.email github-actions@github.com
          git add .
          git commit -m "generated ${{steps.prep.outputs.tags}}"
          git push
```
a jelikož budeme v kroku - name: Build and publish image to Github buildovat image přidáme do repa i dockerfile na který se odvoláváme
```sh
#Dockerfile
FROM alpine:3.12.0 AS build

# The Hugo version
ARG VERSION=0.75.0

ADD https://github.com/gohugoio/hugo/releases/download/v${VERSION}/hugo_${VERSION}_Linux-64bit.tar.gz /hugo.tar.gz
RUN tar -zxvf hugo.tar.gz
RUN /hugo version

# We add git to the build stage, because Hugo needs it with --enableGitInfo
RUN apk add --no-cache git

# The source files are copied to /site
COPY . /site
WORKDIR /site

# And then we just run Hugo
# RUN /hugo --minify --enableGitInfo
RUN /hugo --minify 

# stage 2
#FROM nginx:1.19.2-alpine
FROM nginxinc/nginx-unprivileged

USER root
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/log/nginx
RUN chgrp -R root /var/cache/nginx /var/run /var/log/nginx && \
    chmod -R 770 /var/cache/nginx /var/run /var/log/nginx

USER nginx
WORKDIR /usr/share/nginx/html/

# Clean the default public folder
RUN rm -fr * .??*

# This inserts a line in the default config file, including our file "expires.inc"
RUN sed -i '9i\        include /etc/nginx/conf.d/expires.inc;\n' /etc/nginx/conf.d/default.conf

# The file "expires.inc" is copied into the image
COPY _docker/expires.inc /etc/nginx/conf.d/expires.inc
#RUN chmod 0644 /etc/nginx/conf.d/expires.inc

# Finally, the "public" folder generated by Hugo in the previous stage
# is copied into the public fold of nginx
COPY --from=build /site/public /usr/share/nginx/html
```
Action samotná reaguje na trigger push do master branche
```sh
on:
  push:
    branches:
      - master
```
Udělá tedy build image, výsledný artifakt push do CR ghcr.io  

A po úspěšném buildu notifikuje druhé repo v kterém jsou manifesty pro Kubernetes a zapíše nový název image, tasky
- name: Inform ARGO repo that build is success
- name: Change field image in deployment
- name: Commit changes to ARGO repo


## CONTINUOS DEPLOYMENT
Půjde jen o automatickou aplikaci nových manifestů do kubernetes.  
Zde by samozřejmě šlo provést kubectl apply na manifesty a nasadit tak nové manifesty jako rolling update napřímo, ale rozhodl
jsem se použít GITOPS přístup, tedy na Kubernetes sedí aplikace ARGOCD která sleduje repozitář z manifesty a při jeho změně automaticky
nasadí upravené manifesty.
{{< figure src="argo.png" caption="argo" >}}


## PŘEHLED nástrojů

**CI-CD nástroje**

Github Actions  
Gitlab CI/CD  
Azure Devops  
Jenkins   
Tekton  
ArgoCD (pouze CD)  
Flux (pouze CD)  
Travis CI(pouze CI)  

!je jich daleko vic tohle jsou pouze které znám já!
