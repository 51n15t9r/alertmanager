# Copyright 2015 The Prometheus Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Needs to be defined before including Makefile.common to auto-generate targets
DOCKER_ARCHS ?= amd64 armv7 arm64 ppc64le s390x

include Makefile.common

FRONTEND_DIR             = $(BIN_DIR)/ui/app
TEMPLATE_DIR             = $(BIN_DIR)/template
DOCKER_IMAGE_NAME       ?= alertmanager

STATICCHECK_IGNORE =

.PHONY: build-all
# Will build both the front-end as well as the back-end
build-all: assets apiv2 build

.PHONY: assets
assets: asset/assets_vfsdata.go

.PHONY: assets-tarball
assets-tarball: ui/app/script.js ui/app/index.html
	scripts/package_assets.sh

asset/assets_vfsdata.go: ui/app/script.js ui/app/index.html ui/app/lib template/default.tmpl template/email.tmpl
	GO111MODULE=$(GO111MODULE) $(GO) generate $(GOOPTS) ./asset
	@$(GOFMT) -w ./asset

ui/app/script.js: $(shell find ui/app/src -iname *.elm) api/v2/openapi.yaml
	cd $(FRONTEND_DIR) && $(MAKE) script.js

template/email.tmpl: template/email.html
	cd $(TEMPLATE_DIR) && $(MAKE) email.tmpl

.PHONY: apiv2
apiv2: api/v2/models api/v2/restapi api/v2/client

SWAGGER = docker run \
	--user=$(shell id -u $(USER)):$(shell id -g $(USER)) \
	--rm \
	-v $(shell pwd):/go/src/github.com/prometheus/alertmanager \
	-w /go/src/github.com/prometheus/alertmanager quay.io/goswagger/swagger:v0.30.3

api/v2/models api/v2/restapi api/v2/client: api/v2/openapi.yaml
	-rm -r api/v2/{client,models,restapi}
	$(SWAGGER) generate server -f api/v2/openapi.yaml --copyright-file=COPYRIGHT.txt --exclude-main -A alertmanager --target api/v2/
	$(SWAGGER) generate client -f api/v2/openapi.yaml --copyright-file=COPYRIGHT.txt --skip-models --target api/v2

.PHONY: clean
clean:
	- @rm -rf asset/assets_vfsdata.go \
                  api/v2/models api/v2/restapi api/v2/client
	- @cd $(FRONTEND_DIR) && $(MAKE) clean

govulncheck: install-govulncheck
	govulncheck ./...

install-govulncheck:
	which govulncheck || go install golang.org/x/vuln/cmd/govulncheck@latest
