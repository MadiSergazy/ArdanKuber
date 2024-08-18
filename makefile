# Check to see if we can use ash, in Alpine images, or default to BASH.
SHELL_PATH = /bin/ash
SHELL = $(if $(wildcard $(SHELL_PATH)),/bin/ash,/bin/bash)

run:
	go run app/services/sales-api/main.go | go run app/tooling/logfmt/main.go

# ==============================================================================
# CLASS NOTES
#
# RSA Keys
# 	To generate a private/public key PEM file.
# 	$ openssl genpkey -algorithm RSA -out private.pem -pkeyopt rsa_keygen_bits:2048
# 	$ openssl rsa -pubout -in private.pem -out public.pem

# ==============================================================================
# Define dependencies

GOLANG          := golang:1.21.3
ALPINE          := alpine:3.18
KIND            := kindest/node:v1.27.3
POSTGRES        := postgres:15.4
VAULT           := hashicorp/vault:1.15
GRAFANA         := grafana/grafana:10.1.0
PROMETHEUS      := prom/prometheus:v2.47.0
TEMPO           := grafana/tempo:2.2.0
LOKI            := grafana/loki:2.9.0
PROMTAIL        := grafana/promtail:2.9.0

KIND_CLUSTER    := ardan-starter-cluster
NAMESPACE       := sales-system
APP             := sales
BASE_IMAGE_NAME := ardanlabs/service
SERVICE_NAME    := sales-api
VERSION         := 0.0.1
SERVICE_IMAGE   := $(BASE_IMAGE_NAME)/$(SERVICE_NAME):$(VERSION)
METRICS_IMAGE   := $(BASE_IMAGE_NAME)/$(SERVICE_NAME)-metrics:$(VERSION)

# VERSION       := "0.0.1-$(shell git rev-parse --short HEAD)"

# ==============================================================================
# Running from within k8s/kind

dev-up:
	kind create cluster \
		--image $(KIND) \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/dev/kind-config.yaml

	kubectl wait --timeout=120s --namespace=local-path-storage --for=condition=Available deployment/local-path-provisioner

#kind create cluster: This is the kind command that creates a new local Kubernetes cluster.
#--image $(KIND): This specifies the base image for the Kubernetes nodes in the cluster.
#--name $(KIND_CLUSTER): This specifies the name of the kind cluster
#--config zarf/k8s/dev/kind-config.yaml: This option points to a custom configuration file that defines additional
#settings for the kind cluster, such as the number of nodes, networking options, and more
#if you do changes in kind config file you woud need to restart whole cluster

dev-down:
	kind delete cluster --name $(KIND_CLUSTER)


# ------------------------------------------------------------------------------

dev-status:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

#kubectl get nodes: This command lists all the nodes in the Kubernetes cluster.
#-o wide: This option provides additional information in the output, including internal/external IP addresses, OS image, kernel version, and container runtime version of each node.
#kubectl get svc: This command lists all services in the Kubernetes cluster.
#-o wide: This option provides additional information about the services, such as the cluster IP, external IP (if applicable), and the node port mapping.
#kubectl get pods: This command lists all pods in the Kubernetes cluster.
#-o wide: This option provides extra details about the pods, such as their node assignment (i.e., which node the pod is running on) and IP address.
#--watch: This flag makes the command continuously monitor the pods' status and updates the output whenever the status changes in real-time.
#--all-namespaces: This flag ensures that pods from all namespaces (not just the default namespace) are shown in the output.


# ==============================================================================
# Building containers

all: service

service:
	docker build \
		-f zarf/docker/dockerfile.service \
		-t $(SERVICE_IMAGE) \
		--build-arg BUILD_REF=$(VERSION) \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		.


# ==============================================================================
# Modules support

tidy:
	go mod tidy
	go mod vendor

test-race:
	CGO_ENABLED=1 go test -race -count=1 ./...

test-only:
	CGO_ENABLED=0 go test -count=1 ./...

lint:
	CGO_ENABLED=0 go vet ./...
	staticcheck -checks=all ./...

vuln-check:
	govulncheck ./...

test: test-only lint vuln-check

test-race: test-race lint vuln-check