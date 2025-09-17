FROM ubuntu:22.04

RUN apt-get update -y && apt-get install -y \
    ca-certificates curl unzip gnupg software-properties-common python3-pip git jq \
    docker.io groff less && rm -rf /var/lib/apt/lists/*

# awscli v2
RUN curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip \
 && unzip -q awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip

# terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg \
 | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
 https://apt.releases.hashicorp.com jammy main" > /etc/apt/sources.list.d/hashicorp.list \
 && apt-get update -y && apt-get install -y terraform && rm -rf /var/lib/apt/lists/*

# kubectl (có thể đổi version)
RUN set -eux; \
    apt-get update -y && apt-get install -y gpg ca-certificates && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
      | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
      > /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update -y && apt-get install -y kubectl && \
    rm -rf /var/lib/apt/lists/*

# helm
RUN curl -sSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# ansible
RUN pip3 install --no-cache-dir ansible boto3 botocore kubernetes openshift
