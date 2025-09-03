FROM registry.access.redhat.com/ubi9/ubi:${RHEL_VERSION:-latest}

# Big thanks and credit to the coder crew and https://github.com/coder/code-server
# coder use ubuntu hence the need for a RHEL/CentOS/Fedora based OCI Image

ARG TARGETPLATFORM

ENV PASSWORD=${PASSWORD:-changeme}

LABEL maintainer="Tok - Tony Kay tony.g.kay@gmail.com"

COPY entrypoint.sh /usr/bin/entrypoint.sh

RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
      ARCHITECTURE=amd64; \
    elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
      ARCHITECTURE=arm64; \
    fi \
    && dnf upgrade -y \
    && dnf install -y https://github.com/coder/code-server/releases/download/v4.4.0/code-server-4.4.0-${ARCHITECTURE}.rpm \
      sudo \
      python-devel \
    && useradd devops \
    && echo "devops ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && chmod +x /usr/bin/entrypoint.sh \
    && dnf clean all \
    && rm -rf /var/cache/dnf /root/.cache

USER devops
WORKDIR /home/devops

EXPOSE 8080

ENTRYPOINT ["/usr/bin/entrypoint.sh"]

CMD ["code-server", "--bind-addr", "0.0.0.0:8080"]
