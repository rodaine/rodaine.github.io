.PHONY: bootstrap
bootstrap: vendor node_modules

.PHONY: build
build: bootstrap
	@npm run build \
		& bundle exec jekyll build \
		& wait

.PHONY: serve
serve: bootstrap
	@trap 'kill 0' SIGINT; \
		npx webpack -w \
		& bundle exec jekyll serve -w -D -H localhost \
		& wait

.PHONY: serve-ssl
serve-ssl: bootstrap _mkcert/localhost+2.pem
	@trap 'kill 0' SIGINT; \
		npx webpack -w \
		& bundle exec jekyll serve \
			-w -D -H localhost \
			--ssl-cert _mkcert/localhost+2.pem \
			--ssl-key _mkcert/localhost+2-key.pem \
		& wait

.PHONY: update
update:
	@npm update \
		& bundle update \
		& wait

node_modules:
	@npm install

vendor:
	@bundle install

_mkcert/localhost+2.pem: # https://github.com/FiloSottile/mkcert
	@mkcert -cert-file \
		_mkcert/localhost+2.pem \
		-key-file _mkcert/localhost+2-key.pem \
		localhost 127.0.0.1 ::1
