# HCM Local Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a Docker Compose + Tilt local development environment for all HCM services running on top of the DIGIT platform, with pre-seeded database, Kong gateway, and hot-swap support.

**Architecture:** All services (DIGIT core + HCM) run as pre-built Docker images from `egovio/*`. Infrastructure uses PostgreSQL+PgBouncer, Redis, Redpanda (Kafka-compatible), and MinIO. Database is pre-seeded via Flyway migrations + SQL dumps (boundaries, MDMS, users, workflows, projects, localizations). Kong API gateway routes all traffic. Tilt provides dev dashboard with hot-swap: flip a flag to build any service from local source with live-reload.

**Tech Stack:** Docker Compose, Tilt, PostgreSQL 16, PgBouncer, Redis 7.2, Redpanda v24.1, MinIO, Kong 3.6, Spring Boot (Java 17), Node.js 20

**Reference:** The CRS local-setup at `/Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/` is the pattern to follow.

---

## File Structure

```
/Users/subha/Code/HCM/local-setup/
├── Tiltfile                              # Dev dashboard with hot-swap
├── Tiltfile.db-dump                      # Quick-start (pre-built only, no build tools needed)
├── docker-compose.yml                    # All services definition
├── .env                                  # Image tags, configurable variables
├── .gitignore                            # Exclude runtime artifacts
├── configs/
│   └── persister/                        # Persister YAML configs (mounted into egov-persister)
│       ├── household-persister.yml
│       ├── individual-persister.yml
│       ├── project-persister.yml
│       ├── facility-persister.yml
│       ├── product-persister.yml
│       ├── stock-persister.yml
│       ├── referral-management-persister.yml
│       ├── hrms-employee-persister.yml
│       ├── hrm-employee-update-persister.yml
│       ├── pgr-services-persister.yml
│       ├── service-request-persister.yml
│       ├── id-pool-persister.yml
│       ├── id-pool-dispatch-log-persister.yml
│       ├── egov-workflow-v2-persister.yml
│       ├── mdms-persister.yml
│       └── boundary-persister.yml
├── db/
│   ├── 01_seed_data_dump.sql              # Base data (boundaries, MDMS, products) - renamed from downloaded file
│   ├── 02_hcm_seed_data.sql              # Users, workflows, projects, facilities, staff
│   └── 03_localization_seed_data.sql     # 104K localization messages (3 locales)
├── kong/
│   └── kong.yml                          # Declarative API gateway config
├── scripts/
│   ├── health-check.sh                   # Verify all services are healthy
│   └── smoke-tests.sh                    # Basic API validation
└── seeds/                                # Original Postman collections (reference only)
    ├── HCM seed.postman_collection.json
    └── Localization_Seed_Script.postman_collection.json
```

---

## Task 1: Create `.env` file with all image tags and configuration variables

**Files:**
- Create: `local-setup/.env`

This file centralises every image tag and tunable variable so that docker-compose.yml stays clean and upgrades are a one-line change.

- [ ] **Step 1: Create `.env`**

```env
# ============================================================
# HCM Local Setup - Environment Configuration
# ============================================================

# --- Infrastructure ---
POSTGRES_IMAGE=postgres:16
PGBOUNCER_IMAGE=egovio/pgbouncer:latest
REDIS_IMAGE=redis:7.2.4-alpine
REDPANDA_IMAGE=redpandadata/redpanda:v24.1.1
MINIO_IMAGE=minio/minio:RELEASE.2024-01-16T16-07-38Z
KONG_IMAGE=kong:3.6

# --- Database ---
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=egov

# --- DIGIT Core Service Images ---
MDMS_IMAGE=egovio/mdms-v2:v2.9.2-4a60f20
ENC_IMAGE=egovio/egov-enc-service:v2.9.2-4a60f20
IDGEN_IMAGE=egovio/egov-idgen:v2.9.2-4a60f20
USER_IMAGE=egovio/egov-user:master-fa75ba8
WORKFLOW_IMAGE=egovio/egov-workflow-v2:v2.9.2-4a60f20
LOCALIZATION_IMAGE=egovio/egov-localization:v2.9.2-4a60f20
BOUNDARY_IMAGE=egovio/boundary-service:v2.9.2-4a60f20
ACCESSCONTROL_IMAGE=egovio/egov-accesscontrol:v2.9.2-4a60f20
PERSISTER_IMAGE=egovio/egov-persister:v2.9.2-4a60f20
FILESTORE_IMAGE=egovio/egov-filestore:v2.9.2-4a60f20
URL_SHORTENING_IMAGE=egovio/egov-url-shortening:v2.9.2-4a60f20

# --- HCM Service Images (app) ---
# To hot-swap a service: change image to locally built tag or set LOCAL_BUILD in Tiltfile
FACILITY_IMAGE=egovio/facility:v1.2.0-b8e24ab705-33
HOUSEHOLD_IMAGE=egovio/household:v1.2.0-8900208f3e-74
INDIVIDUAL_IMAGE=egovio/health-individual:v1.2.0-a059ce1ffd-101
PROJECT_IMAGE=egovio/health-project:v1.2.0-8900208f3e-108
PRODUCT_IMAGE=egovio/product:v1.2.0-8900208f3e-1
REFERRAL_IMAGE=egovio/referralmanagement:v1.2.1-80c43fbe9a-100
STOCK_IMAGE=egovio/stock:v1.2.0-8900208f3e-67
HEALTH_HRMS_IMAGE=egovio/health-hrms:v1.4.0-683e9da909-13
HEALTH_PGR_IMAGE=egovio/health-pgr-services:v1.2.0-bf5fea17f1-7
HEALTH_SERVICE_REQUEST_IMAGE=egovio/health-service-request:v1.2.0-01c2b65440-5
PROJECT_FACTORY_IMAGE=egovio/project-factory:v0.4.0-500e69c6fa-587
PLAN_SERVICE_IMAGE=egovio/plan-service:latest
CENSUS_SERVICE_IMAGE=egovio/census-service:latest
EXCEL_INGESTION_IMAGE=egovio/excel-ingestion:latest
TRANSFORMER_IMAGE=egovio/transformer:latest
RESOURCE_GENERATOR_IMAGE=egovio/resource-generator:latest
BENEFICIARY_IDGEN_IMAGE=egovio/beneficiary-idgen:latest
BOUNDARY_MANAGEMENT_IMAGE=egovio/boundary-management:latest
DASHBOARD_ANALYTICS_IMAGE=egovio/dashboard-analytics:latest
SURVEY_SERVICES_IMAGE=egovio/egov-survey-services:latest
AUTH_PROXY_IMAGE=egovio/auth-proxy:latest

# --- HCM DB Migration Images ---
FACILITY_DB_IMAGE=egovio/facility-db:v1.2.0-b8e24ab705-33
HOUSEHOLD_DB_IMAGE=egovio/household-db:v1.2.0-8900208f3e-74
INDIVIDUAL_DB_IMAGE=egovio/health-individual-db:v1.2.0-a059ce1ffd-101
PROJECT_DB_IMAGE=egovio/health-project-db:v1.2.0-8900208f3e-108
PRODUCT_DB_IMAGE=egovio/product-db:v1.2.0-8900208f3e-1
REFERRAL_DB_IMAGE=egovio/referralmanagement-db:v1.2.1-80c43fbe9a-100
STOCK_DB_IMAGE=egovio/stock-db:v1.2.0-8900208f3e-67
HEALTH_HRMS_DB_IMAGE=egovio/health-hrms-db:v1.4.0-683e9da909-13
HEALTH_PGR_DB_IMAGE=egovio/health-pgr-services-db:v1.2.0-bf5fea17f1-7
HEALTH_SERVICE_REQUEST_DB_IMAGE=egovio/health-service-request-db:v1.2.0-01c2b65440-5
PLAN_SERVICE_DB_IMAGE=egovio/plan-service-db:latest
CENSUS_SERVICE_DB_IMAGE=egovio/census-service-db:latest
EXCEL_INGESTION_DB_IMAGE=egovio/excel-ingestion-db:latest
BENEFICIARY_IDGEN_DB_IMAGE=egovio/beneficiary-idgen-db:latest
SURVEY_SERVICES_DB_IMAGE=egovio/egov-survey-services-db:latest
PROJECT_FACTORY_DB_IMAGE=egovio/project-factory-db:latest
BOUNDARY_MANAGEMENT_DB_IMAGE=egovio/boundary-management-db:latest

# --- Ports (external) ---
KONG_PROXY_PORT=18000
KONG_ADMIN_PORT=18001
POSTGRES_PORT=15432
REDIS_PORT=16379
REDPANDA_PORT=19092
MINIO_PORT=19000
MINIO_CONSOLE_PORT=19001
```

- [ ] **Step 2: Create `.gitignore`**

```gitignore
# Runtime
.tilt-dev/
*.pyc
__pycache__/

# Docker volumes (managed by compose)
postgres_data/
minio_data/
redpanda_data/

# OS
.DS_Store
```

- [ ] **Step 3: Verify files created**

Run: `cat /Users/subha/Code/HCM/local-setup/.env | head -5`
Expected: Shows the header comments

- [ ] **Step 4: Commit**

```bash
cd /Users/subha/Code/HCM/local-setup
git add .env .gitignore
git commit -m "feat(local-setup): add .env with image tags and .gitignore"
```

---

## Task 2: Collect and create persister configuration files

**Files:**
- Create: `local-setup/configs/persister/` (15 YAML files)

Source persister YAMLs from the HCM services source code and the CRS reference. These are mounted read-only into the egov-persister container.

- [ ] **Step 1: Copy HCM service persister configs**

Copy from each service's `src/main/resources/` directory:

```bash
cd /Users/subha/Code/HCM/local-setup
mkdir -p configs/persister

# Health services
cp ../health-campaign-services/health-services/household/src/main/resources/household-persister.yml configs/persister/
cp ../health-campaign-services/health-services/individual/src/main/resources/individual-persister.yml configs/persister/
cp ../health-campaign-services/health-services/project/src/main/resources/project-persister.yml configs/persister/
cp ../health-campaign-services/health-services/facility/src/main/resources/facility-persister.yml configs/persister/
cp ../health-campaign-services/health-services/product/src/main/resources/product-persister.yml configs/persister/
cp ../health-campaign-services/health-services/stock/src/main/resources/stock-persister.yml configs/persister/
cp ../health-campaign-services/health-services/referralmanagement/src/main/resources/referral-management-persister.yml configs/persister/

# Core services
cp ../health-campaign-services/core-services/egov-hrms/src/main/resources/config/hrms-employee-persister.yml configs/persister/
cp ../health-campaign-services/core-services/egov-hrms/src/main/resources/config/hrm-employee-update-persister.yml configs/persister/
cp ../health-campaign-services/core-services/pgr-services/src/main/resources/pgr-services-persister.yml configs/persister/
cp ../health-campaign-services/core-services/service-request/src/main/resources/service-request-persister.yml configs/persister/
cp ../health-campaign-services/core-services/beneficiary-idgen/src/main/resources/config/id-pool-persister.yml configs/persister/
cp ../health-campaign-services/core-services/beneficiary-idgen/src/main/resources/config/id-pool-dispatch-log-persister.yml configs/persister/
```

- [ ] **Step 2: Copy DIGIT core persister configs from CRS reference**

```bash
# These are for DIGIT platform services (workflow, MDMS, boundary)
cp /Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/configs/persister/egov-workflow-v2-persister.yml configs/persister/
cp /Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/configs/persister/mdms-persister.yml configs/persister/
cp /Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/configs/persister/boundary-persister.yml configs/persister/
```

- [ ] **Step 3: Verify all files present**

Run: `ls -la configs/persister/ | wc -l`
Expected: 16+ files

- [ ] **Step 4: Commit**

```bash
git add configs/persister/
git commit -m "feat(local-setup): add persister configs for all HCM and DIGIT services"
```

---

## Task 3: Create Kong declarative configuration

**Files:**
- Create: `local-setup/kong/kong.yml`

Reference: `/Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/kong/kong.yml` (268 lines)

Kong provides a single entry point at `:18000` routing to all backend services. Each service gets a route with `strip_path: false` so the context path is preserved.

- [ ] **Step 1: Create `kong/kong.yml`**

```yaml
_format_version: "3.0"

consumers:
- username: hcm-dev
  keyauth_credentials:
  - key: hcm-dev-api-key-change-me
  tags: [development]

plugins:
- name: cors
  config:
    origins: ['*']
    methods: [GET, POST, PUT, PATCH, DELETE, OPTIONS]
    headers:
    - Accept
    - Authorization
    - X-API-Key
    - auth-token
    - Content-Type
    - Content-Disposition
    - tenantId
    credentials: true
    max_age: 3600

- name: request-size-limiting
  config:
    allowed_payload_size: 10
    size_unit: megabytes

services:

# ==================== DIGIT Core Services ====================

- name: mdms-service
  url: http://egov-mdms-service:8094
  tags: [core]
  routes:
  - name: mdms-route
    paths: [/mdms-v2]
    strip_path: false

- name: user-service
  url: http://egov-user:8080
  tags: [core]
  routes:
  - name: user-route
    paths: [/user]
    strip_path: false

- name: enc-service
  url: http://egov-enc-service:8080
  tags: [core]
  routes:
  - name: enc-route
    paths: [/egov-enc-service]
    strip_path: false

- name: idgen-service
  url: http://egov-idgen:8080
  tags: [core]
  routes:
  - name: idgen-route
    paths: [/egov-idgen]
    strip_path: false

- name: workflow-service
  url: http://egov-workflow-v2:8080
  tags: [core]
  routes:
  - name: workflow-route
    paths: [/egov-workflow-v2]
    strip_path: false

- name: localization-service
  url: http://egov-localization:8080
  tags: [core]
  routes:
  - name: localization-route
    paths: [/localization]
    strip_path: false

- name: boundary-service
  url: http://boundary-service:8080
  tags: [core]
  routes:
  - name: boundary-route
    paths: [/boundary-service]
    strip_path: false

- name: accesscontrol-service
  url: http://egov-accesscontrol:8080
  tags: [core]
  routes:
  - name: accesscontrol-route
    paths: [/access]
    strip_path: false

- name: persister-service
  url: http://egov-persister:8080
  tags: [core]
  routes:
  - name: persister-route
    paths: [/common-persist]
    strip_path: false

- name: filestore-service
  url: http://egov-filestore:8080
  tags: [core]
  routes:
  - name: filestore-route
    paths: [/filestore]
    strip_path: false

- name: url-shortening-service
  url: http://egov-url-shortening:8080
  tags: [core]
  routes:
  - name: url-shortening-route
    paths: [/egov-url-shortening]
    strip_path: false

# ==================== HCM Health Services ====================

- name: project-service
  url: http://health-project:8080
  tags: [hcm]
  routes:
  - name: project-route
    paths: [/health-project]
    strip_path: false

- name: household-service
  url: http://household:8080
  tags: [hcm]
  routes:
  - name: household-route
    paths: [/household]
    strip_path: false

- name: individual-service
  url: http://health-individual:8080
  tags: [hcm]
  routes:
  - name: individual-route
    paths: [/health-individual]
    strip_path: false

- name: facility-service
  url: http://facility:8080
  tags: [hcm]
  routes:
  - name: facility-route
    paths: [/facility]
    strip_path: false

- name: product-service
  url: http://product:8080
  tags: [hcm]
  routes:
  - name: product-route
    paths: [/product]
    strip_path: false

- name: stock-service
  url: http://stock:8080
  tags: [hcm]
  routes:
  - name: stock-route
    paths: [/stock]
    strip_path: false

- name: referralmanagement-service
  url: http://referralmanagement:8080
  tags: [hcm]
  routes:
  - name: referralmanagement-route
    paths: [/referralmanagement]
    strip_path: false

- name: plan-service
  url: http://plan-service:8080
  tags: [hcm]
  routes:
  - name: plan-route
    paths: [/plan-service]
    strip_path: false

- name: census-service
  url: http://census-service:8080
  tags: [hcm]
  routes:
  - name: census-route
    paths: [/census-service]
    strip_path: false

- name: excel-ingestion-service
  url: http://excel-ingestion:8080
  tags: [hcm]
  routes:
  - name: excel-ingestion-route
    paths: [/excel-ingestion]
    strip_path: false

- name: transformer-service
  url: http://transformer:8080
  tags: [hcm]
  routes:
  - name: transformer-route
    paths: [/transformer]
    strip_path: false

- name: resource-generator-service
  url: http://resource-generator:8083
  tags: [hcm]
  routes:
  - name: resource-generator-route
    paths: [/resource-generator]
    strip_path: false

- name: beneficiary-idgen-service
  url: http://beneficiary-idgen:8088
  tags: [hcm]
  routes:
  - name: beneficiary-idgen-route
    paths: [/beneficiary-idgen]
    strip_path: false

# ==================== HCM Core Services ====================

- name: health-hrms-service
  url: http://health-hrms:8080
  tags: [hcm]
  routes:
  - name: health-hrms-route
    paths: [/health-hrms]
    strip_path: false
  - name: egov-hrms-route
    paths: [/egov-hrms]
    strip_path: false

- name: health-pgr-service
  url: http://health-pgr-services:8080
  tags: [hcm]
  routes:
  - name: health-pgr-route
    paths: [/pgr-services]
    strip_path: false

- name: health-service-request
  url: http://health-service-request:8080
  tags: [hcm]
  routes:
  - name: service-request-route
    paths: [/service-request]
    strip_path: false

- name: project-factory-service
  url: http://project-factory:8080
  tags: [hcm]
  routes:
  - name: project-factory-route
    paths: [/project-factory]
    strip_path: false

- name: boundary-management-service
  url: http://boundary-management:8080
  tags: [hcm]
  routes:
  - name: boundary-management-route
    paths: [/boundary-management]
    strip_path: false

- name: dashboard-analytics-service
  url: http://dashboard-analytics:8080
  tags: [hcm]
  routes:
  - name: dashboard-analytics-route
    paths: [/dashboard-analytics]
    strip_path: false

- name: survey-services
  url: http://egov-survey-services:8080
  tags: [hcm]
  routes:
  - name: survey-route
    paths: [/egov-survey-services]
    strip_path: false

- name: auth-proxy-service
  url: http://auth-proxy:8085
  tags: [hcm]
  routes:
  - name: auth-proxy-route
    paths: [/auth-proxy]
    strip_path: false

# ==================== Health Check Routes ====================

- name: health-mdms
  url: http://egov-mdms-service:8094
  routes:
  - name: health-mdms-route
    paths: [/health/mdms]
    strip_path: true
  plugins:
  - name: request-transformer
    config:
      replace:
        uri: /mdms-v2/health

- name: health-user
  url: http://egov-user:8080
  routes:
  - name: health-user-route
    paths: [/health/user]
    strip_path: true
  plugins:
  - name: request-transformer
    config:
      replace:
        uri: /user/health

- name: health-workflow
  url: http://egov-workflow-v2:8080
  routes:
  - name: health-workflow-route
    paths: [/health/workflow]
    strip_path: true
  plugins:
  - name: request-transformer
    config:
      replace:
        uri: /egov-workflow-v2/health

- name: health-project
  url: http://health-project:8080
  routes:
  - name: health-project-health-route
    paths: [/health/project]
    strip_path: true
  plugins:
  - name: request-transformer
    config:
      replace:
        uri: /health-project/health
```

- [ ] **Step 2: Commit**

```bash
git add kong/
git commit -m "feat(local-setup): add Kong declarative gateway config for all services"
```

---

## Task 4: Create `docker-compose.yml` — Infrastructure services

**Files:**
- Create: `local-setup/docker-compose.yml`

Build the docker-compose in stages. This task covers infrastructure only: PostgreSQL, PgBouncer, Redis, Redpanda, MinIO.

Reference pattern: `/Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/docker-compose.yml` lines 1-160.

- [ ] **Step 1: Create docker-compose.yml with infrastructure services**

The file is large — write the infrastructure block first. Key points:
- PostgreSQL 16 with a healthcheck on `pg_isready`, creates `egov` database
- DO NOT mount `db/` to `/docker-entrypoint-initdb.d/` — seed data must load AFTER Flyway migrations (handled by `db-seed` container in Task 5)
- PgBouncer with network alias `postgres` so services connect through it transparently
- Redpanda with `--kafka-addr` configured, network alias `kafka`
- Redis with healthcheck
- MinIO for filestore

**Seed data flow:**
1. PostgreSQL starts with empty `egov` database
2. Services start and each runs its own Flyway migrations (creates all tables)
3. `db-seed` container (Task 5) waits for tables to exist, then loads seed SQL

Include the `db-seed` service definition here:
```yaml
  db-seed:
    build:
      context: ./docker/db-seed
    depends_on:
      postgres-db:
        condition: service_healthy
    environment:
      DB_HOST: postgres-db
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: ${POSTGRES_DB}
      DB_USER: ${POSTGRES_USER}
    volumes:
      - ./db:/seeds:ro
    networks:
      - egov-network
    restart: "no"
```

- [ ] **Step 2: Verify infrastructure starts**

Run: `docker compose up -d postgres-db redis redpanda minio`
Expected: All 4 containers healthy within 30 seconds

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(local-setup): add docker-compose infrastructure services"
```

---

## Task 5: Create db-seed container for loading seed SQL data

**Files:**
- Create: `local-setup/docker/db-seed/Dockerfile`
- Create: `local-setup/docker/db-seed/load-seeds.sh`

Each Spring Boot service runs its own Flyway migrations on startup (`spring.flyway.enabled=true`), so we do NOT need a separate Flyway runner. We only need a `db-seed` container that waits for tables to exist (created by Flyway), then loads the seed SQL files.

The seed dump (`seed_data_dump_v2.0.sql`) writes to tables owned by `boundary-service`, `egov-mdms-service`, and `product`. The `db-seed` container must wait for ALL these tables to exist before loading data.

- [ ] **Step 1: Create db-seed Dockerfile**

File: `local-setup/docker/db-seed/Dockerfile`
```dockerfile
FROM postgres:16-alpine
COPY load-seeds.sh /load-seeds.sh
RUN chmod +x /load-seeds.sh
ENTRYPOINT ["/load-seeds.sh"]
```

- [ ] **Step 2: Create seed loader script**

File: `local-setup/docker/db-seed/load-seeds.sh`
```bash
#!/bin/sh
set -e

DB_HOST="${DB_HOST:-postgres-db}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-egov}"
DB_USER="${DB_USER:-postgres}"

PSQL="PGPASSWORD=$POSTGRES_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"

echo "Waiting for PostgreSQL..."
until PGPASSWORD=$POSTGRES_PASSWORD pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; do
  sleep 2
done

# Wait for required tables to be created by Flyway migrations
# These tables are needed by the seed data dump
echo "Waiting for Flyway migrations to create tables..."
for tbl in boundary boundary_hierarchy boundary_relationship eg_mdms_data product product_variant eg_user eg_userrole eg_wf_businessservice_v2 eg_wf_state_v2 eg_wf_action_v2 project project_staff project_resource project_facility facility address message; do
  echo -n "  Waiting for table: $tbl..."
  until PGPASSWORD=$POSTGRES_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1 FROM $tbl LIMIT 0" >/dev/null 2>&1; do
    sleep 3
  done
  echo " OK"
done

# Check if seed data already loaded (idempotent)
BOUNDARY_COUNT=$(PGPASSWORD=$POSTGRES_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -tAc "SELECT COUNT(*) FROM boundary;" 2>/dev/null || echo "0")
if [ "$BOUNDARY_COUNT" -gt "0" ]; then
  echo "Seed data already loaded ($BOUNDARY_COUNT boundaries). Skipping."
  exit 0
fi

echo "Loading seed data..."
for sql_file in /seeds/*.sql; do
  echo "Loading: $(basename $sql_file)"
  PGPASSWORD=$POSTGRES_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$sql_file"
done

echo "Seed data loaded successfully."
```

- [ ] **Step 3: Verify Dockerfile builds**

```bash
cd /Users/subha/Code/HCM/local-setup
docker build -t hcm-db-seed ./docker/db-seed
```
Expected: Builds successfully

- [ ] **Step 4: Commit**

```bash
git add docker/db-seed/
git commit -m "feat(local-setup): add db-seed container for loading seed SQL data"
```

---

## Task 6: Create `docker-compose.yml` — DIGIT Core services

**Files:**
- Modify: `local-setup/docker-compose.yml` (add 12 DIGIT core services)

Each DIGIT core service follows the CRS pattern:
- Pre-built `egovio/*` image from `.env`
- Environment variables for database (pointing to pgbouncer), Kafka (redpanda), Redis
- Health check on the service's `/health` endpoint
- `depends_on` infrastructure services
- Resource limits (~256-512MB each)
- Connected to `egov-network`

Key environment variables common to all DIGIT core services:
```
SPRING_DATASOURCE_URL=jdbc:postgresql://pgbouncer:5432/egov
SPRING_DATASOURCE_USERNAME=postgres
SPRING_DATASOURCE_PASSWORD=postgres
SPRING_KAFKA_BOOTSTRAP_SERVERS=redpanda:9092
SPRING_REDIS_HOST=redis
SPRING_REDIS_PORT=6379
JAVA_TOOL_OPTIONS=-Xms64m -Xmx256m
SERVER_SERVLET_CONTEXT_PATH=/service-path
FLYWAY_ENABLED=true
OTEL_TRACES_EXPORTER=none
```

- [ ] **Step 1: Add all 12 DIGIT core services to docker-compose.yml**

Services to add (following CRS patterns exactly):
1. `egov-mdms-service` — port 8094, context `/mdms-v2`
2. `egov-enc-service` — port 8080, context `/egov-enc-service`, needs MASTER_PASSWORD, MASTER_SALT, MASTER_INITIALVECTOR
3. `egov-idgen` — port 8080, context `/egov-idgen`
4. `egov-user` — port 8080, context `/user`, needs Redis for sessions
5. `egov-workflow-v2` — port 8080, context `/egov-workflow-v2`
6. `egov-localization` — port 8080, context `/localization`, needs Redis
7. `boundary-service` — port 8080, context `/boundary-service`
8. `egov-accesscontrol` — port 8080, context `/access`
9. `egov-persister` — port 8080, mount persister configs
10. `egov-filestore` — port 8080, context `/filestore`, needs MinIO config
11. `egov-url-shortening` — port 8080
12. `pgbouncer` — connection pooler

Copy the exact environment variable patterns from the CRS `docker-compose.yml` for each service, adjusting only image tags (from `.env`).

- [ ] **Step 2: Verify DIGIT core services start**

Run: `docker compose up -d` (infrastructure + core)
Expected: All DIGIT core services reach healthy state

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(local-setup): add DIGIT core services to docker-compose"
```

---

## Task 7: Create `docker-compose.yml` — HCM services

**Files:**
- Modify: `local-setup/docker-compose.yml` (add 21 HCM services + Kong)

Each HCM service follows the same pattern as DIGIT core but with additional service-specific environment variables. The key difference: all external service hosts must point to the local Docker network names instead of `dev.digit.org`.

Common HCM service environment overrides (replacing remote URLs with local):
```
EGOV_MDMS_HOST=http://egov-mdms-service:8094
EGOV_USER_HOST=http://egov-user:8080
EGOV_IDGEN_HOST=http://egov-idgen:8080
EGOV_WORKFLOW_HOST=http://egov-workflow-v2:8080
EGOV_LOCALIZATION_HOST=http://egov-localization:8080
EGOV_BOUNDARY_HOST=http://boundary-service:8080
EGOV_ENC_HOST=http://egov-enc-service:8080
EGOV_FILESTORE_HOST=http://egov-filestore:8080
EGOV_HRMS_HOST=http://health-hrms:8080
EGOV_URL_SHORTENING_HOST=http://egov-url-shortening:8080
```

HCM services pointing to each other locally:
```
EGOV_PROJECT_HOST=http://health-project:8080
EGOV_HOUSEHOLD_HOST=http://household:8080
EGOV_INDIVIDUAL_HOST=http://health-individual:8080
EGOV_FACILITY_HOST=http://facility:8080
EGOV_PRODUCT_HOST=http://product:8080
EGOV_STOCK_HOST=http://stock:8080
EGOV_PLAN_SERVICE_HOST=http://plan-service:8080
EGOV_CENSUS_HOST=http://census-service:8080
EGOV_PROJECT_FACTORY_HOST=http://project-factory:8080
EGOV_EXCEL_INGESTION_HOST=http://excel-ingestion:8080
BENEFICIARY_IDGEN_HOST=http://beneficiary-idgen:8088
```

- [ ] **Step 1: Add Java-based HCM services**

Add these 18 Java/Spring Boot services:
1. `health-project` — PROJECT_IMAGE, port 8080, context `/health-project`
2. `household` — HOUSEHOLD_IMAGE, port 8080, context `/household`
3. `health-individual` — INDIVIDUAL_IMAGE, port 8080, context `/health-individual`
4. `facility` — FACILITY_IMAGE, port 8080, context `/facility`
5. `product` — PRODUCT_IMAGE, port 8080, context `/product`
6. `stock` — STOCK_IMAGE, port 8080, context `/stock`
7. `referralmanagement` — REFERRAL_IMAGE, port 8080, context `/referralmanagement`
8. `plan-service` — PLAN_SERVICE_IMAGE, port 8080, context `/plan-service`
9. `census-service` — CENSUS_SERVICE_IMAGE, port 8080, context `/census-service`
10. `excel-ingestion` — EXCEL_INGESTION_IMAGE, port 8080, context `/excel-ingestion`
11. `transformer` — TRANSFORMER_IMAGE, port 8080, context `/transformer`
12. `resource-generator` — RESOURCE_GENERATOR_IMAGE, port 8083, context `/resource-generator`
13. `beneficiary-idgen` — BENEFICIARY_IDGEN_IMAGE, port 8088, context `/beneficiary-idgen`
14. `health-hrms` — HEALTH_HRMS_IMAGE, port 8080, context `/health-hrms`
15. `health-pgr-services` — HEALTH_PGR_IMAGE, port 8080, context `/pgr-services`
16. `health-service-request` — HEALTH_SERVICE_REQUEST_IMAGE, port 8080
17. `egov-survey-services` — SURVEY_SERVICES_IMAGE, port 8080
18. `dashboard-analytics` — DASHBOARD_ANALYTICS_IMAGE, port 8080

- [ ] **Step 2: Add Node.js-based HCM services**

3 Node.js services with different env var patterns:

1. `project-factory` — PROJECT_FACTORY_IMAGE, port 8080, context `/project-factory`
   ```
   EGOV_HOST=http://kong:8000
   DB_HOST=pgbouncer
   KAFKA_BROKER_HOST=redpanda:9092
   REDIS_HOST=redis
   ```

2. `boundary-management` — BOUNDARY_MANAGEMENT_IMAGE, port 8080, context `/boundary-management`
   ```
   EGOV_HOST=http://kong:8000
   DB_HOST=pgbouncer
   KAFKA_BROKER_HOST=redpanda:9092
   ```

3. `auth-proxy` — AUTH_PROXY_IMAGE, port 8085
   ```
   EGOV_USER_HOST=http://egov-user:8080/
   ```

- [ ] **Step 3: Add Kong gateway**

```yaml
  kong:
    image: ${KONG_IMAGE}
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /kong/kong.yml
      KONG_PROXY_LISTEN: 0.0.0.0:8000
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    volumes:
      - ./kong/kong.yml:/kong/kong.yml:ro
    ports:
      - "${KONG_PROXY_PORT}:8000"
      - "${KONG_ADMIN_PORT}:8001"
    healthcheck:
      test: ["CMD", "kong", "health"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - egov-network
```

- [ ] **Step 4: Add networks and volumes section**

```yaml
networks:
  egov-network:
    driver: bridge

volumes:
  postgres_data:
  minio_data:
  redpanda_data:
```

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(local-setup): add all HCM services and Kong gateway to docker-compose"
```

---

## Task 8: Generate `02_hcm_seed_data.sql` from Postman collection

**Files:**
- Rename: `local-setup/db/seed_data_dump_v2.0.sql` → `local-setup/db/01_seed_data_dump.sql`
- Create: `local-setup/db/02_hcm_seed_data.sql`

Convert the HCM Seed Postman collection into SQL INSERT statements. Use fixed UUIDs for reproducibility.

Reference: `/Users/subha/Code/HCM/local-setup/seeds/HCM seed.postman_collection.json`

Table schemas known from Task 3 analysis. The Postman collection creates:
- 6 users (eg_user + eg_userrole)
- 2 workflow business services (eg_wf_businessservice_v2 + eg_wf_state_v2 + eg_wf_action_v2)
- 3 projects (project + project_address)
- 2 facilities (facility + address)
- 15 project_staff assignments
- project_resource mappings
- 6 project_facility mappings

- [ ] **Step 1: Rename base seed dump**

```bash
cd /Users/subha/Code/HCM/local-setup/db
mv seed_data_dump_v2.0.sql 01_seed_data_dump.sql
```

- [ ] **Step 2: Create 02_hcm_seed_data.sql**

Write SQL INSERT statements matching the Postman collection's data exactly. Use deterministic UUIDs (e.g., `00000000-0000-0000-0000-000000000001`). Passwords must be bcrypt-hashed (the Postman uses `eGov@1234` — the hash from the CRS dump can be reused).

Key data points from Postman analysis:
- Tenant: `mz`
- Superadmin roles: HRMS_ADMIN, HELPDESK_USER, REGISTRAR, SYSTEM_ADMINISTRATOR, etc.
- PGR Workflow: states PENDINGFORASSIGNMENT → PENDINGATLME → RESOLVED/REJECTED → CLOSED
- HCMMUSTERROLL Workflow: APPROVAL_PENDING → APPROVED
- 3 Projects: SMC (individual), LLIN Bednet (household), IRS (household)
- Products: SP, AQ, LLIN Bednet, IRS (already in seed_data_dump_v2.0.sql)

The SQL file should be idempotent (use `INSERT ... ON CONFLICT DO NOTHING` where possible).

- [ ] **Step 2: Verify SQL loads cleanly**

Run against a test database:
```bash
docker compose up -d postgres-db
# Wait for healthy
docker compose exec postgres-db psql -U postgres -d egov -f /docker-entrypoint-initdb.d/hcm-seed-data.sql
```

- [ ] **Step 3: Commit**

```bash
git add db/hcm-seed-data.sql
git commit -m "feat(local-setup): add HCM seed data SQL (users, workflows, projects, facilities)"
```

---

## Task 9: Generate `03_localization_seed_data.sql` from Postman collection

**Files:**
- Create: `local-setup/db/03_localization_seed_data.sql`

Convert the Localization Seed Script Postman collection (104,747 messages across 52 modules × 3 locales) into SQL INSERT statements for the `message` table.

Reference: `/Users/subha/Code/HCM/local-setup/seeds/Localization_Seed_Script.postman_collection .json` (note: filename has a space before `.json`)

Table schema:
```sql
message (id, locale, code, message, tenantid, module, createdby, createddate)
```

- [ ] **Step 1: Write a script to extract localization data from Postman JSON**

Create a Python script at `local-setup/scripts/generate-localization-sql.py` that:
1. Reads the Postman collection JSON
2. Extracts all `messages` arrays from each request body
3. Generates SQL COPY or INSERT statements
4. Writes to `db/localization-seed-data.sql`

```python
#!/usr/bin/env python3
"""Extract localization messages from Postman collection into SQL."""
import json
import uuid
import sys

def extract_messages(collection_path, output_path):
    with open(collection_path) as f:
        collection = json.load(f)

    messages = []
    for folder in collection.get('item', []):
        if folder.get('name') == 'Auth':
            continue
        locale_folder = folder.get('name', '')
        for request_item in folder.get('item', []):
            body = request_item.get('request', {}).get('body', {})
            raw = body.get('raw', '{}')
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                continue
            for msg in payload.get('messages', []):
                messages.append({
                    'locale': msg.get('locale', ''),
                    'code': msg.get('code', ''),
                    'message': msg.get('message', ''),
                    'module': msg.get('module', ''),
                })

    with open(output_path, 'w') as out:
        out.write("-- Localization seed data: {} messages\\n".format(len(messages)))
        out.write("-- Generated from Localization_Seed_Script.postman_collection.json\\n\\n")

        for msg in messages:
            msg_id = str(uuid.uuid5(uuid.NAMESPACE_DNS,
                f"{msg['module']}:{msg['code']}:{msg['locale']}"))
            # Escape single quotes in message text
            escaped_message = msg['message'].replace("'", "''")
            escaped_code = msg['code'].replace("'", "''")
            out.write(
                f"INSERT INTO message (id, locale, code, message, tenantid, module, createdby, createddate) "
                f"VALUES ('{msg_id}', '{msg['locale']}', '{escaped_code}', '{escaped_message}', "
                f"'mz', '{msg['module']}', 1, NOW()) ON CONFLICT (id) DO NOTHING;\\n"
            )

    print(f"Generated {len(messages)} INSERT statements to {output_path}")

if __name__ == '__main__':
    extract_messages(
        'seeds/Localization_Seed_Script.postman_collection .json',
        'db/03_localization_seed_data.sql'
    )
```

- [ ] **Step 2: Run the script**

```bash
cd /Users/subha/Code/HCM/local-setup
python3 scripts/generate-localization-sql.py
```

Expected: `db/localization-seed-data.sql` created with ~104K INSERT statements

- [ ] **Step 3: Verify SQL is valid**

```bash
head -20 db/localization-seed-data.sql
wc -l db/localization-seed-data.sql
```

Expected: ~104,747 lines of INSERT statements

- [ ] **Step 4: Commit**

```bash
git add scripts/generate-localization-sql.py db/localization-seed-data.sql
git commit -m "feat(local-setup): add localization seed SQL (104K messages, 3 locales)"
```

---

## Task 10: Add resource limits to docker-compose.yml

**Files:**
- Modify: `local-setup/docker-compose.yml`

With 40+ containers, resource limits are critical to avoid exhausting system memory. Add `deploy.resources.limits` to every service.

- [ ] **Step 1: Add resource limits to all services**

Guidelines (matching CRS patterns):
```yaml
# Infrastructure
postgres-db:   memory: 768M, cpus: '1'
pgbouncer:     memory: 128M, cpus: '0.25'
redis:         memory: 128M, cpus: '0.25'
redpanda:      memory: 512M, cpus: '0.5'
minio:         memory: 256M, cpus: '0.25'

# DIGIT Core (each)
egov-mdms-service:   memory: 512M
egov-localization:   memory: 512M
egov-user:           memory: 512M
# other core:        memory: 256M

# HCM Services (each): memory: 256M-384M
# Node.js services:   memory: 512M (project-factory needs more)

# Kong:              memory: 256M
```

Total estimated: ~12.5 GB

- [ ] **Step 2: Validate compose file**

```bash
docker compose config --quiet
```
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(local-setup): add resource limits to all services"
```

---

## Task 11: Create the Tiltfile

**Files:**
- Create: `local-setup/Tiltfile`

Reference: `/Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/Tiltfile` (417 lines)

The Tiltfile provides:
1. Docker Compose integration (`docker_compose()`)
2. Resource labels for Tilt UI grouping (infrastructure, core, hcm, gateway)
3. Resource dependencies (startup ordering)
4. Health check links
5. Hot-swap support: `LOCAL_BUILD` dict to build services from source
6. Custom buttons for common operations (health-check, smoke-tests, nuke-db)

- [ ] **Step 1: Create `Tiltfile`**

```python
# HCM Local Setup - Tilt Development Environment
# ================================================
# Usage:
#   tilt up                    # Start all services (pre-built images)
#   tilt up -- --local project # Start with 'project' built from source
#
# Hot-swap: Set LOCAL_BUILD entries to True to build from source
# ================================================

load('ext://dotenv', 'dotenv')
dotenv()

# ---------- Configuration ----------

# Services that can be built locally (set True to build from source)
LOCAL_BUILD = {
    'health-project': False,
    'household': False,
    'health-individual': False,
    'facility': False,
    'product': False,
    'stock': False,
    'referralmanagement': False,
    'plan-service': False,
    'census-service': False,
    'excel-ingestion': False,
    'transformer': False,
    'resource-generator': False,
    'beneficiary-idgen': False,
    'health-hrms': False,
    'health-pgr-services': False,
    'health-service-request': False,
    'egov-survey-services': False,
    'dashboard-analytics': False,
    'project-factory': False,
    'boundary-management': False,
    'auth-proxy': False,
}

# Parse CLI args: tilt up -- --local project,household
config.define_string('local', args=True)
cfg = config.parse()
local_services = cfg.get('local', '').split(',') if cfg.get('local', '') else []
for svc in local_services:
    svc = svc.strip()
    if svc in LOCAL_BUILD:
        LOCAL_BUILD[svc] = True
        print('Local build enabled for: ' + svc)

# CI mode detection
CI_MODE = os.getenv('CI', '') != '' or os.getenv('TILT_CI', '') != ''

# Path to HCM services source
HCM_SERVICES_PATH = os.path.abspath('../health-campaign-services')

# ---------- Docker Compose ----------

docker_compose('./docker-compose.yml')

# ---------- Infrastructure ----------

dc_resource('postgres-db', labels=['infrastructure'])
dc_resource('pgbouncer', labels=['infrastructure'],
    resource_deps=['postgres-db'])
dc_resource('redis', labels=['infrastructure'])
dc_resource('redpanda', labels=['infrastructure'])
dc_resource('minio', labels=['infrastructure'])

# ---------- DIGIT Core Services ----------

dc_resource('egov-mdms-service', labels=['core'],
    resource_deps=['pgbouncer', 'redpanda'],
    links=[link('http://localhost:18000/mdms-v2/health', 'Health')])

dc_resource('egov-enc-service', labels=['core'],
    resource_deps=['pgbouncer'],
    links=[link('http://localhost:18000/egov-enc-service/health', 'Health')])

dc_resource('egov-idgen', labels=['core'],
    resource_deps=['pgbouncer', 'redpanda'],
    links=[link('http://localhost:18000/egov-idgen/health', 'Health')])

dc_resource('egov-user', labels=['core'],
    resource_deps=['pgbouncer', 'redpanda', 'redis', 'egov-enc-service'],
    links=[link('http://localhost:18000/user/health', 'Health')])

dc_resource('egov-workflow-v2', labels=['core'],
    resource_deps=['pgbouncer', 'redpanda'],
    links=[link('http://localhost:18000/egov-workflow-v2/health', 'Health')])

dc_resource('egov-localization', labels=['core'],
    resource_deps=['pgbouncer', 'redpanda', 'redis'],
    links=[link('http://localhost:18000/localization/health', 'Health')])

dc_resource('boundary-service', labels=['core'],
    resource_deps=['pgbouncer', 'redpanda'],
    links=[link('http://localhost:18000/boundary-service/health', 'Health')])

dc_resource('egov-accesscontrol', labels=['core'],
    resource_deps=['pgbouncer', 'redpanda'],
    links=[link('http://localhost:18000/access/health', 'Health')])

dc_resource('egov-persister', labels=['core'],
    resource_deps=['pgbouncer', 'redpanda'],
    links=[link('http://localhost:18000/common-persist/health', 'Health')])

dc_resource('egov-filestore', labels=['core'],
    resource_deps=['pgbouncer', 'minio'],
    links=[link('http://localhost:18000/filestore/health', 'Health')])

dc_resource('egov-url-shortening', labels=['core'],
    resource_deps=['pgbouncer'])

# ---------- HCM Services ----------

dc_resource('health-project', labels=['hcm'],
    resource_deps=['egov-idgen', 'egov-user', 'egov-workflow-v2', 'egov-localization'],
    links=[link('http://localhost:18000/health-project/health', 'Health')])

dc_resource('household', labels=['hcm'],
    resource_deps=['egov-idgen', 'egov-user'],
    links=[link('http://localhost:18000/household/health', 'Health')])

dc_resource('health-individual', labels=['hcm'],
    resource_deps=['egov-idgen', 'egov-enc-service'],
    links=[link('http://localhost:18000/health-individual/health', 'Health')])

dc_resource('facility', labels=['hcm'],
    resource_deps=['egov-idgen', 'egov-user'],
    links=[link('http://localhost:18000/facility/health', 'Health')])

dc_resource('product', labels=['hcm'],
    resource_deps=['egov-idgen'],
    links=[link('http://localhost:18000/product/health', 'Health')])

dc_resource('stock', labels=['hcm'],
    resource_deps=['egov-idgen'],
    links=[link('http://localhost:18000/stock/health', 'Health')])

dc_resource('referralmanagement', labels=['hcm'],
    resource_deps=['egov-idgen'],
    links=[link('http://localhost:18000/referralmanagement/health', 'Health')])

dc_resource('plan-service', labels=['hcm'],
    resource_deps=['egov-mdms-service', 'egov-workflow-v2'],
    links=[link('http://localhost:18000/plan-service/health', 'Health')])

dc_resource('census-service', labels=['hcm'],
    resource_deps=['egov-workflow-v2'],
    links=[link('http://localhost:18000/census-service/health', 'Health')])

dc_resource('excel-ingestion', labels=['hcm'],
    resource_deps=['egov-filestore', 'egov-localization'],
    links=[link('http://localhost:18000/excel-ingestion/health', 'Health')])

dc_resource('transformer', labels=['hcm'],
    resource_deps=['egov-mdms-service'],
    links=[link('http://localhost:18000/transformer/health', 'Health')])

dc_resource('resource-generator', labels=['hcm'],
    resource_deps=['egov-mdms-service'],
    links=[link('http://localhost:18000/resource-generator/health', 'Health')])

dc_resource('beneficiary-idgen', labels=['hcm'],
    resource_deps=['pgbouncer', 'redpanda', 'redis'],
    links=[link('http://localhost:18000/beneficiary-idgen/health', 'Health')])

dc_resource('health-hrms', labels=['hcm'],
    resource_deps=['egov-idgen', 'egov-user', 'egov-mdms-service'],
    links=[link('http://localhost:18000/health-hrms/health', 'Health')])

dc_resource('health-pgr-services', labels=['hcm'],
    resource_deps=['egov-idgen', 'egov-user', 'egov-workflow-v2'],
    links=[link('http://localhost:18000/pgr-services/health', 'Health')])

dc_resource('health-service-request', labels=['hcm'],
    resource_deps=['pgbouncer', 'redpanda'])

dc_resource('egov-survey-services', labels=['hcm'],
    resource_deps=['pgbouncer', 'redpanda'])

dc_resource('dashboard-analytics', labels=['hcm'],
    resource_deps=['pgbouncer'])

dc_resource('project-factory', labels=['hcm'],
    resource_deps=['health-project', 'egov-mdms-service'],
    links=[link('http://localhost:18000/project-factory/health', 'Health')])

dc_resource('boundary-management', labels=['hcm'],
    resource_deps=['boundary-service', 'egov-mdms-service'],
    links=[link('http://localhost:18000/boundary-management/health', 'Health')])

dc_resource('auth-proxy', labels=['hcm'],
    resource_deps=['egov-user'])

# ---------- Gateway ----------

dc_resource('kong', labels=['gateway'],
    links=[
        link('http://localhost:18000', 'Proxy'),
        link('http://localhost:18001', 'Admin'),
    ])

# ---------- Seed Data ----------

dc_resource('db-seed', labels=['infrastructure'],
    resource_deps=['egov-mdms-service'])

# ---------- Hot-swap: Local Build Support ----------

# Java service hot-swap pattern
# IMAGE_MAP maps service names to their docker-compose image refs (from .env)
IMAGE_MAP = {
    'health-project': os.getenv('PROJECT_IMAGE', ''),
    'household': os.getenv('HOUSEHOLD_IMAGE', ''),
    'health-individual': os.getenv('INDIVIDUAL_IMAGE', ''),
    'facility': os.getenv('FACILITY_IMAGE', ''),
    'product': os.getenv('PRODUCT_IMAGE', ''),
    'stock': os.getenv('STOCK_IMAGE', ''),
    'referralmanagement': os.getenv('REFERRAL_IMAGE', ''),
    'plan-service': os.getenv('PLAN_SERVICE_IMAGE', ''),
    'census-service': os.getenv('CENSUS_SERVICE_IMAGE', ''),
    'excel-ingestion': os.getenv('EXCEL_INGESTION_IMAGE', ''),
    'transformer': os.getenv('TRANSFORMER_IMAGE', ''),
    'resource-generator': os.getenv('RESOURCE_GENERATOR_IMAGE', ''),
    'beneficiary-idgen': os.getenv('BENEFICIARY_IDGEN_IMAGE', ''),
    'health-hrms': os.getenv('HEALTH_HRMS_IMAGE', ''),
    'health-pgr-services': os.getenv('HEALTH_PGR_IMAGE', ''),
    'health-service-request': os.getenv('HEALTH_SERVICE_REQUEST_IMAGE', ''),
    'egov-survey-services': os.getenv('SURVEY_SERVICES_IMAGE', ''),
    'dashboard-analytics': os.getenv('DASHBOARD_ANALYTICS_IMAGE', ''),
}

def java_hot_swap(service_name, source_dir, context_path):
    """Enable local build with live-reload for a Java Spring Boot service."""
    if not LOCAL_BUILD.get(service_name, False):
        return

    image_ref = IMAGE_MAP.get(service_name, '')
    if not image_ref:
        print('WARNING: No image ref for ' + service_name + ', skipping hot-swap')
        return

    src_path = os.path.join(HCM_SERVICES_PATH, source_dir)

    local_resource(
        service_name + '-compile',
        'cd ' + src_path + ' && mvn package -DskipTests -q && unzip -o target/*.jar -d target/extracted',
        deps=[src_path + '/src', src_path + '/pom.xml'],
        labels=['build'],
    )

    # Use the exact image ref from docker-compose so Tilt knows to replace it
    docker_build(
        image_ref,
        context=src_path + '/target/extracted',
        dockerfile_contents="""
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app
COPY . .
ENTRYPOINT ["java", "-cp", "BOOT-INF/classes:BOOT-INF/lib/*", "-Dserver.servlet.context-path=""" + context_path + """"]
""",
        live_update=[
            sync(src_path + '/target/extracted/BOOT-INF/lib', '/app/BOOT-INF/lib'),
            sync(src_path + '/target/extracted/BOOT-INF/classes', '/app/BOOT-INF/classes'),
        ],
    )

# Register hot-swap for Java services
java_hot_swap('health-project', 'health-services/project', '/health-project')
java_hot_swap('household', 'health-services/household', '/household')
java_hot_swap('health-individual', 'health-services/individual', '/health-individual')
java_hot_swap('facility', 'health-services/facility', '/facility')
java_hot_swap('product', 'health-services/product', '/product')
java_hot_swap('stock', 'health-services/stock', '/stock')
java_hot_swap('referralmanagement', 'health-services/referralmanagement', '/referralmanagement')
java_hot_swap('plan-service', 'health-services/plan-service', '/plan-service')
java_hot_swap('census-service', 'health-services/census-service', '/census-service')
java_hot_swap('excel-ingestion', 'health-services/excel-ingestion', '/excel-ingestion')
java_hot_swap('transformer', 'health-services/transformer', '/transformer')
java_hot_swap('resource-generator', 'health-services/resource-generator', '/resource-generator')
java_hot_swap('beneficiary-idgen', 'core-services/beneficiary-idgen', '/beneficiary-idgen')
java_hot_swap('health-hrms', 'core-services/egov-hrms', '/health-hrms')
java_hot_swap('health-pgr-services', 'core-services/pgr-services', '/pgr-services')
java_hot_swap('health-service-request', 'core-services/service-request', '/service-request')
java_hot_swap('egov-survey-services', 'core-services/egov-survey-services', '/egov-survey-services')
java_hot_swap('dashboard-analytics', 'core-services/dashboard-analytics', '/dashboard-analytics')

# ---------- Custom Buttons ----------

cmd_button(
    name='health-check',
    argv=['./scripts/health-check.sh'],
    location=location.NAV,
    icon_name='favorite',
    text='Health Check',
)

cmd_button(
    name='smoke-tests',
    argv=['./scripts/smoke-tests.sh'],
    location=location.NAV,
    icon_name='science',
    text='Smoke Tests',
)

cmd_button(
    name='nuke-db',
    argv=['sh', '-c', 'docker compose down -v && docker compose up -d postgres-db'],
    location=location.NAV,
    icon_name='delete_forever',
    text='Nuke DB',
    requires_confirmation=True,
)
```

- [ ] **Step 2: Commit**

```bash
git add Tiltfile
git commit -m "feat(local-setup): add Tiltfile with hot-swap support and dev dashboard"
```

---

## Task 12: Create `Tiltfile.db-dump` (quick-start variant)

**Files:**
- Create: `local-setup/Tiltfile.db-dump`

A simpler Tiltfile that only uses pre-built images — no Maven/Node.js needed. For users who just want to run the stack.

- [ ] **Step 1: Create `Tiltfile.db-dump`**

```python
# HCM Local Setup - Quick Start (pre-built images only)
# =====================================================
# Usage: tilt up -f Tiltfile.db-dump
# No build tools (Maven, Node.js) required.
# =====================================================

load('ext://dotenv', 'dotenv')
dotenv()

docker_compose('./docker-compose.yml')

# --- Infrastructure ---
dc_resource('postgres-db', labels=['infrastructure'])
dc_resource('pgbouncer', labels=['infrastructure'], resource_deps=['postgres-db'])
dc_resource('redis', labels=['infrastructure'])
dc_resource('redpanda', labels=['infrastructure'])
dc_resource('minio', labels=['infrastructure'])
dc_resource('db-seed', labels=['infrastructure'], resource_deps=['egov-mdms-service'])

# --- DIGIT Core ---
for svc in ['egov-mdms-service', 'egov-enc-service', 'egov-idgen', 'egov-user',
            'egov-workflow-v2', 'egov-localization', 'boundary-service',
            'egov-accesscontrol', 'egov-persister', 'egov-filestore', 'egov-url-shortening']:
    dc_resource(svc, labels=['core'], resource_deps=['pgbouncer', 'redpanda'])

# --- HCM Services ---
for svc in ['health-project', 'household', 'health-individual', 'facility', 'product',
            'stock', 'referralmanagement', 'plan-service', 'census-service',
            'excel-ingestion', 'transformer', 'resource-generator', 'beneficiary-idgen',
            'health-hrms', 'health-pgr-services', 'health-service-request',
            'egov-survey-services', 'dashboard-analytics', 'project-factory',
            'boundary-management', 'auth-proxy']:
    dc_resource(svc, labels=['hcm'])

# --- Gateway ---
dc_resource('kong', labels=['gateway'],
    links=[link('http://localhost:18000', 'API Gateway')])
```

- [ ] **Step 2: Commit**

```bash
git add Tiltfile.db-dump
git commit -m "feat(local-setup): add Tiltfile.db-dump for quick-start without build tools"
```

---

## Task 13: Create health check and smoke test scripts

**Files:**
- Create: `local-setup/scripts/health-check.sh`
- Create: `local-setup/scripts/smoke-tests.sh`

Reference: `/Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/scripts/health-check.sh`

- [ ] **Step 1: Create health-check.sh**

```bash
#!/bin/bash
# Health check for all HCM local-setup services
set -e

BASE_URL="${BASE_URL:-http://localhost:18000}"
PASS=0
FAIL=0

check() {
  local name=$1
  local path=$2
  if curl -sf "${BASE_URL}${path}" >/dev/null 2>&1; then
    echo "  ✓ ${name}"
    PASS=$((PASS + 1))
  else
    echo "  ✗ ${name}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Infrastructure ==="
check "PostgreSQL" "" # checked via pgbouncer
echo "(PostgreSQL checked via service connectivity)"

echo ""
echo "=== DIGIT Core Services ==="
check "MDMS" "/mdms-v2/health"
check "User" "/user/health"
check "IDGEN" "/egov-idgen/health"
check "Workflow" "/egov-workflow-v2/health"
check "Localization" "/localization/health"
check "Boundary" "/boundary-service/health"
check "AccessControl" "/access/health"
check "Persister" "/common-persist/health"
check "Filestore" "/filestore/health"
check "ENC" "/egov-enc-service/health"

echo ""
echo "=== HCM Services ==="
check "Project" "/health-project/health"
check "Household" "/household/health"
check "Individual" "/health-individual/health"
check "Facility" "/facility/health"
check "Product" "/product/health"
check "Stock" "/stock/health"
check "Referral Mgmt" "/referralmanagement/health"
check "Plan Service" "/plan-service/health"
check "Census Service" "/census-service/health"
check "Excel Ingestion" "/excel-ingestion/health"
check "Transformer" "/transformer/health"
check "Resource Generator" "/resource-generator/health"
check "Beneficiary IDGen" "/beneficiary-idgen/health"
check "Health HRMS" "/health-hrms/health"
check "Health PGR" "/pgr-services/health"
check "Project Factory" "/project-factory/health"
check "Boundary Mgmt" "/boundary-management/health"

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ $FAIL -eq 0 ] && exit 0 || exit 1
```

- [ ] **Step 2: Create smoke-tests.sh**

```bash
#!/bin/bash
# Smoke tests for HCM local-setup - validates core API functionality
set -e

BASE_URL="${BASE_URL:-http://localhost:18000}"
TENANT="mz"

echo "=== HCM Smoke Tests ==="

# Test 1: MDMS search
echo -n "MDMS Search... "
RESULT=$(curl -sf -X POST "${BASE_URL}/mdms-v2/v1/_search" \
  -H "Content-Type: application/json" \
  -d '{"RequestInfo":{"apiId":"asset-services","ver":null,"ts":null,"action":null,"did":"1","key":"","msgId":"20170310130900|en_IN","authToken":"","userInfo":{"id":1,"uuid":"1","userName":"admin","type":"EMPLOYEE","tenantId":"mz"}},"MdmsCriteria":{"tenantId":"mz","schemaCode":"tenant.tenants"}}')
echo "$RESULT" | grep -q "tenants" && echo "PASS" || echo "FAIL"

# Test 2: User OAuth token
echo -n "User OAuth... "
TOKEN=$(curl -sf -X POST "${BASE_URL}/user/oauth/token" \
  -H "Authorization: Basic ZWdvdi11c2VyLWNsaWVudDo=" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&scope=read&username=SU-0001&password=eGov@1234&tenantId=${TENANT}&userType=EMPLOYEE" 2>/dev/null)
echo "$TOKEN" | grep -q "access_token" && echo "PASS" || echo "FAIL"

# Test 3: Boundary search
echo -n "Boundary Search... "
RESULT=$(curl -sf "${BASE_URL}/boundary-service/boundary-relationships/_search?tenantId=${TENANT}&hierarchyType=ADMIN&includeChildren=true&boundaryType=Country")
echo "$RESULT" | grep -q "boundary" && echo "PASS" || echo "FAIL"

echo ""
echo "=== Smoke tests complete ==="
```

- [ ] **Step 3: Make scripts executable and commit**

```bash
chmod +x scripts/health-check.sh scripts/smoke-tests.sh
git add scripts/
git commit -m "feat(local-setup): add health-check and smoke-test scripts"
```

---

## Task 14: Write the complete `docker-compose.yml`

**Files:**
- Modify: `local-setup/docker-compose.yml` — finalize the complete file

This is the main task that assembles the full docker-compose.yml. It was built incrementally in Tasks 4-7 but needs to be finalized as one coherent file.

Key patterns from CRS reference to replicate:
- All services on `egov-network`
- PgBouncer aliases as `postgres` on the network
- Redpanda aliases as `kafka` on the network
- Health checks with `start_period: 120s` for Java services
- Resource limits (256M-512M per service)
- `JAVA_TOOL_OPTIONS: -Xms64m -Xmx256m` for all Java services
- `OTEL_TRACES_EXPORTER: none` for all services
- `SPRING_FLYWAY_ENABLED: true` for services with DB migrations
- `SPRING_FLYWAY_TABLE` set uniquely per service to avoid Flyway table conflicts (all services share one DB)

**Critical detail:** Since all services share one PostgreSQL database (`egov`), each service's Flyway must use a separate history table. Set `SPRING_FLYWAY_TABLE=flyway_schema_history_{service}` for each service.

- [ ] **Step 1: Write the complete docker-compose.yml**

This is a large file (~1500+ lines). Implement it following all the patterns documented above.

Reference the CRS docker-compose.yml at `/Users/subha/Code/Citizen-Complaint-Resolution-System/local-setup/docker-compose.yml` for exact syntax.

- [ ] **Step 2: Validate compose file**

```bash
cd /Users/subha/Code/HCM/local-setup
docker compose config --quiet
```
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat(local-setup): finalize complete docker-compose.yml with all services"
```

---

## Task 15: Integration test — bring up the full stack

- [ ] **Step 1: Pull all images**

```bash
cd /Users/subha/Code/HCM/local-setup
docker compose pull
```

- [ ] **Step 2: Start infrastructure first**

```bash
docker compose up -d postgres-db redis redpanda minio pgbouncer
```
Wait for all healthy.

- [ ] **Step 3: Start DIGIT core services**

```bash
docker compose up -d egov-mdms-service egov-enc-service egov-idgen egov-user \
  egov-workflow-v2 egov-localization boundary-service egov-accesscontrol \
  egov-persister egov-filestore egov-url-shortening
```
Wait for health checks to pass.

- [ ] **Step 4: Run db-seed**

```bash
docker compose up db-seed
```
Expected: Seed data loaded (boundaries, MDMS, users, projects, localizations).

- [ ] **Step 5: Start HCM services and Kong**

```bash
docker compose up -d
```

- [ ] **Step 6: Run health checks**

```bash
./scripts/health-check.sh
```
Expected: All services pass.

- [ ] **Step 7: Run smoke tests**

```bash
./scripts/smoke-tests.sh
```
Expected: MDMS search, OAuth token, boundary search all pass.

- [ ] **Step 8: Test via Tilt**

```bash
tilt up -f Tiltfile.db-dump
```
Expected: Tilt dashboard shows all services grouped and healthy.

- [ ] **Step 9: Commit any fixes from integration testing**

```bash
git add -A
git commit -m "fix(local-setup): fixes from integration testing"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | `.env` with image tags + `.gitignore` | `.env`, `.gitignore` |
| 2 | Persister configs | `configs/persister/*.yml` (16 files) |
| 3 | Kong gateway config | `kong/kong.yml` |
| 4 | Docker Compose — infrastructure | `docker-compose.yml` |
| 5 | DB seed container | `docker/db-seed/*` |
| 6 | Docker Compose — DIGIT core services | `docker-compose.yml` |
| 7 | Docker Compose — HCM services + Kong | `docker-compose.yml` |
| 8 | SQL seed — users, workflows, projects | `db/02_hcm_seed_data.sql` |
| 9 | SQL seed — localizations | `db/03_localization_seed_data.sql`, `scripts/generate-localization-sql.py` |
| 10 | Resource limits | `docker-compose.yml` |
| 11 | Tiltfile with hot-swap | `Tiltfile` |
| 12 | Quick-start Tiltfile | `Tiltfile.db-dump` |
| 13 | Health check & smoke test scripts | `scripts/*.sh` |
| 14 | Finalize docker-compose.yml | `docker-compose.yml` |
| 15 | Integration test | (all files) |
