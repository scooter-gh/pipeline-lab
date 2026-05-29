FROM myoung34/github-runner:latest

RUN curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - \
    && sudo apt-get install -y nodejs curl ca-certificates \
    && sudo curl -Lo /usr/local/bin/k3d https://github.com/k3d-io/k3d/releases/latest/download/k3d-linux-amd64 \
    && sudo chmod +x /usr/local/bin/k3d \
    && sudo curl -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && sudo chmod +x /usr/local/bin/kubectl \
    && sudo curl -Lo /tmp/helm.tar.gz https://get.helm.sh/helm-v3.17.0-linux-amd64.tar.gz \
    && sudo tar -C /tmp -xzf /tmp/helm.tar.gz \
    && sudo cp /tmp/linux-amd64/helm /usr/local/bin/helm \
    && sudo chmod +x /usr/local/bin/helm \
    && sudo rm -rf /tmp/helm.tar.gz /tmp/linux-amd64 \
    && sudo apt-get clean