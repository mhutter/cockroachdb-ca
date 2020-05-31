# Configuration
COCKROACHDB_VERSION = 20.1.1
CLIENTS = root

# CockroachDB specifics
CRFLAGS = --certs-dir="/data/$(CERTS_DIR)" --ca-key="/data/$(CA_KEY)"
COCKROACH = docker run -it --rm -v "$$(pwd):/data" cockroachdb/cockroach:v$(COCKROACHDB_VERSION) $(CRFLAGS)

# Certificate paths
CERTS_DIR = certs
CA_DIR = ca
CA_KEY = $(CA_DIR)/ca.key
CA_CERT = $(CERTS_DIR)/ca.crt
CLIENT_CERTS = $(addsuffix .crt,$(addprefix $(CERTS_DIR)/client.,$(CLIENTS)))
CLIENT_MANIFESTS = $(addsuffix .secret.yml,$(addprefix cockroachdb-client.,$(CLIENTS)))

manifests: $(CLIENT_MANIFESTS) cockroachdb-node.secret.yml

cockroachdb-node.secret.yml: $(CERTS_DIR)/node.crt $(CLIENT_CERTS)
	kubectl create secret generic cockroach.node \
		--dry-run=client \
		--from-file="$(CERTS_DIR)" \
		-o yaml > "$@"

cockroachdb-client.%.secret.yml: $(CERTS_DIR)/client.%.crt
	kubectl create secret generic cockroachdb.client.$* \
		--dry-run=client \
		--from-file="$(CA_CERT)" \
		--from-file="$(CERTS_DIR)/client.$*.crt" \
		--from-file="$(CERTS_DIR)/client.$*.key" \
		-o yaml > "$@"

$(CERTS_DIR)/node.crt: $(CA_KEY)
	$(COCKROACH) cert create-node \
		localhost 127.0.0.1 \
		cockroachdb-public cockroachdb-public.default cockroachdb-public.default.svc.cluster.local \
		'*.cockroachdb' '*.cockroachdb.default' '*.cockroachdb.default.svc.cluster.local'

$(CERTS_DIR)/client.%.crt: $(CA_KEY)
	$(COCKROACH) cert create-client $*

$(CA_DIR)/ca.key: $(CA_DIR)
	$(COCKROACH) cert create-ca

$(CA_DIR):
	mkdir -p $@

.PHONY: clean
clean:
	rm -rf *.yml ca certs
