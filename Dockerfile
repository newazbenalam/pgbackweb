FROM golang:1.25-trixie AS golang
FROM debian:trixie
LABEL org.opencontainers.image.source="https://github.com/eduardolat/pgbackweb"
# Declare ARG to make it available in the RUN commands
ARG TARGETPLATFORM=linux/amd64
RUN echo "Building for ${TARGETPLATFORM}"
RUN if [ "${TARGETPLATFORM}" != "linux/amd64" ] && [ "${TARGETPLATFORM}" != "linux/arm64" ]; then \
        echo "Unsupported architecture: ${TARGETPLATFORM}" && \
        exit 1; \
    fi

WORKDIR /app
ENV DEBIAN_FRONTEND="noninteractive"
ENV GOBIN="/usr/local/go/bin"
ENV PATH="$PATH:/usr/local/go/bin"

# Install golang from docker image
COPY --from=golang /usr/local/go /usr/local/go

# Install system dependencies and prepare system
RUN set -e && \
    mkdir /tmp/downloads && cd /tmp/downloads && \
    apt update && apt install -y postgresql-common && \
    /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y && \
    apt update && apt install -y \
        wget p7zip-full tzdata git npm \
        postgresql-client-13 postgresql-client-14 \
        postgresql-client-15 postgresql-client-16 \
        postgresql-client-17 postgresql-client-18 && \
    npm install -g n@latest && \
    n 22.19.0 && \
    if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then \
        wget --no-verbose https://github.com/go-task/task/releases/download/v3.45.4/task_linux_arm64.tar.gz && \
        tar -xzf task_linux_arm64.tar.gz && \
        mv ./task /usr/local/bin/task && \
        wget --no-verbose https://github.com/pressly/goose/releases/download/v3.25.0/goose_linux_arm64 && \
        mv ./goose_linux_arm64 /usr/local/bin/goose && \
        wget --no-verbose https://github.com/sqlc-dev/sqlc/releases/download/v1.30.0/sqlc_1.30.0_linux_arm64.tar.gz && \
        tar -xzf sqlc_1.30.0_linux_arm64.tar.gz && \
        mv ./sqlc /usr/local/bin/sqlc && \
        wget --no-verbose https://github.com/golangci/golangci-lint/releases/download/v2.5.0/golangci-lint-2.5.0-linux-arm64.tar.gz && \
        tar -xzf golangci-lint-2.5.0-linux-arm64.tar.gz && \
        mv ./golangci-lint-2.5.0-linux-arm64/golangci-lint /usr/local/bin/golangci-lint; \
    else \
        wget --no-verbose https://github.com/go-task/task/releases/download/v3.45.4/task_linux_amd64.tar.gz && \
        tar -xzf task_linux_amd64.tar.gz && \
        mv ./task /usr/local/bin/task && \
        wget --no-verbose https://github.com/pressly/goose/releases/download/v3.25.0/goose_linux_x86_64 && \
        mv ./goose_linux_x86_64 /usr/local/bin/goose && \
        wget --no-verbose https://github.com/sqlc-dev/sqlc/releases/download/v1.30.0/sqlc_1.30.0_linux_amd64.tar.gz && \
        tar -xzf sqlc_1.30.0_linux_amd64.tar.gz && \
        mv ./sqlc /usr/local/bin/sqlc && \
        wget --no-verbose https://github.com/golangci/golangci-lint/releases/download/v2.5.0/golangci-lint-2.5.0-linux-amd64.tar.gz && \
        tar -xzf golangci-lint-2.5.0-linux-amd64.tar.gz && \
        mv ./golangci-lint-2.5.0-linux-amd64/golangci-lint /usr/local/bin/golangci-lint; \
    fi && \
    chmod +x /usr/local/bin/* && \
    git config --global --add safe.directory '*' && \
    cd /app && rm -rf /tmp/downloads && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir /backups && \
    chmod 777 /backups

##############
# START HERE #
##############

# Copy and install node dependencies
COPY package.json .
COPY package-lock.json .
RUN npm install

# Copy and install go dependencies
COPY go.mod .
COPY go.sum .
RUN go mod download

# Copy the rest of the files
COPY . .

# Build the app
RUN set -e && \
    task fixperms && \
    task build && \
    cp ./dist/change-password /usr/local/bin/change-password && \
    chmod +x /usr/local/bin/change-password

# Run the app
EXPOSE 8085
CMD ["task", "servem"]
