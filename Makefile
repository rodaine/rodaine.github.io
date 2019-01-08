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

serve-ssl: bootstrap
	trap 'kill 0' SIGINT; \
		npx webpack -w \
		& bundle exec jekyll serve \
			-w -H localhost \
			--ssl-cert _mkcert/localhost+2.pem \
			--ssl-key _mkcert/localhost+2-key.pem

.PHONY: update
update:
	npm update \
		& bundle update \
		& wait
