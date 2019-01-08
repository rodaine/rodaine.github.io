.PHONY: bootstrap
bootstrap: vendor node_modules

node_modules:
	npm install

vendor:
	bundle install

.PHONY: build
build: bootstrap
	npx webpack \
		& bundle exec jekyll build \
		& wait

.PHONY: serve
serve: bootstrap
	trap 'kill 0' SIGINT; \
		npx webpack -w \
		& bundle exec jekyll serve -w -H localhost \
		& wait

.PHONY: update
update:
	npm update \
		& bundle update \
		& wait
