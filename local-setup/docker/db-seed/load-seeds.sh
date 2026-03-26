#!/bin/sh
set -e

DB_HOST="${DB_HOST:-postgres-db}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-egov}"
DB_USER="${DB_USER:-postgres}"

echo "Waiting for PostgreSQL..."
until PGPASSWORD=$POSTGRES_PASSWORD pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USER; do
  sleep 2
done

# Wait for required tables to be created by Flyway migrations
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
