.PHONY: build up up-host down logs

build:
	docker compose build --parallel

up: build
	docker compose up -d

up-host: build
	docker compose -f docker-compose.yml -f docker-compose.override-host.yml up -d

down:
	docker compose down --volumes

logs:
	docker compose logs -f --tail=200
