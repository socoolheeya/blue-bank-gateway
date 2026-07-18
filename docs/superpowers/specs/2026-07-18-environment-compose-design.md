# Environment-specific Docker Compose design

## Goal

Run the gateway stack consistently in local, development, and production environments without treating a physically separate Eureka server as a Docker build context.

## Selected approach

Use `docker-compose.yml` as the shared base and merge exactly one environment override at deployment time:

- `docker-compose.local.yml` adds and builds the local Eureka service.
- `docker-compose.dev.yml` configures the gateway for the `dev` Spring profile and requires an external `EUREKA_URI`.
- `docker-compose.prod.yml` configures the gateway for the `prod` Spring profile and requires an external `EUREKA_URI`.

This avoids duplicating the full service definitions while ensuring that remote environments never attempt to read the Eureka server's filesystem.

## Alternatives considered

1. A single Compose file with profiles: compact, but service dependency merging makes it easy for remote deployments to retain an invalid `depends_on: eureka` relationship.
2. Three complete Compose files: explicit, but duplicates Gateway, Nginx, Redis, health checks, networks, and volumes, increasing configuration drift.
3. Base plus overrides (selected): keeps shared configuration centralized and isolates the local-only Eureka lifecycle.

## Composition

The base file owns Nginx, Gateway, Redis, the shared network, and volumes. It has no Eureka service and no `depends_on` entry for Eureka. The gateway reads `EUREKA_URI` from the environment.

The local override adds Eureka with `../blue-bank-eureka-server` as its build context, changes the gateway URI to `http://eureka:8761/eureka`, and adds the local health-based dependency. It uses the `local` Spring profile.

The dev and prod overrides do not define an Eureka container. They select their matching Spring profiles and require `EUREKA_URI` using Compose's `${EUREKA_URI:?message}` validation so deployment fails immediately with a useful error if the external server address is missing.

## Deployment commands

```bash
# Local
docker compose -f docker-compose.yml -f docker-compose.local.yml up --build -d

# Development
docker compose --env-file .env.dev -f docker-compose.yml -f docker-compose.dev.yml up --build -d

# Production
docker compose --env-file .env.prod -f docker-compose.yml -f docker-compose.prod.yml up --build -d
```

The remote environment files must provide a network URL, for example `EUREKA_URI=http://eureka.internal.example.com:8761/eureka`. They never provide a filesystem path.

## Validation

Render every merged configuration with `docker compose config`. Local validation must contain the Eureka service and local service dependency. Dev/prod validation must contain no Eureka service, no Eureka dependency, the correct Spring profile, and the supplied external URI. Finally, run the Gradle test/build task to ensure application compilation succeeds.
