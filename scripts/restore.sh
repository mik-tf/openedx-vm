#!/bin/bash
set -e

# Load environment variables
source ../docker/.env

if [ $# -ne 1 ]; then
  echo "Usage: $0 <backup_directory>"
  exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup directory not found: $BACKUP_DIR"
  exit 1
fi

# Basic validation of backup content
echo "Validating backup integrity..."

# Check for manifest file
if [ ! -f "$BACKUP_DIR/backup_manifest.json" ]; then
  echo "ERROR: No backup manifest found. This doesn't appear to be a valid backup."
  exit 1
fi

# Verify backup components
COMPONENTS=$(cat "$BACKUP_DIR/backup_manifest.json" | grep -o '"components":\[[^]]*\]' | grep -o '"[^"]*"' | grep -v "components" | tr -d '"')
echo "Backup components: $COMPONENTS"

# Check for essential files
if [ ! -f "$BACKUP_DIR/mysql_dump.sql" ]; then
  echo "ERROR: MySQL dump not found in backup."
  exit 1
fi

if [ ! -f "$BACKUP_DIR/openedx_data.tar.gz" ]; then
  echo "ERROR: Open edX data archive not found in backup."
  exit 1
fi

# Verify checksum if present in manifest
if grep -q "checksum" "$BACKUP_DIR/backup_manifest.json"; then
  MANIFEST_CHECKSUM=$(grep -o '"checksum":"[^"]*"' "$BACKUP_DIR/backup_manifest.json" | cut -d':' -f2 | tr -d '"')
  echo "Verifying backup checksum..."

  # Calculate actual checksum of files (excluding manifest)
  CALCULATED_CHECKSUM=$(find "$BACKUP_DIR" -type f -not -name "backup_manifest.json" -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)

  if [ "$MANIFEST_CHECKSUM" != "$CALCULATED_CHECKSUM" ]; then
    echo "WARNING: Backup checksum verification failed!"
    echo "Expected: $MANIFEST_CHECKSUM"
    echo "Actual:   $CALCULATED_CHECKSUM"

    read -p "Continue with restore despite checksum mismatch? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Restore cancelled."
      exit 1
    fi
  else
    echo "Checksum verification passed."
  fi
fi

echo "Backup validation complete. Proceeding with restore..."

# Stop services
echo "Stopping services..."
cd ../docker
docker-compose down

# Restore MySQL database
echo "Restoring MySQL database..."
docker volume rm docker_mysql_data || true
docker-compose up -d mysql
sleep 10  # Wait for MySQL to start
cat "$BACKUP_DIR/mysql_dump.sql" | docker exec -i mysql mysql -u root -p"${MYSQL_ROOT_PASSWORD}"

# Restore Redis if backup exists
if [ -f "$BACKUP_DIR/redis_data.tar.gz" ]; then
  echo "Restoring Redis data..."
  docker volume rm docker_redis_data || true
  docker volume create docker_redis_data
  tar -xzf "$BACKUP_DIR/redis_data.tar.gz" -C /var/lib/docker/volumes/
  docker-compose up -d redis
fi

# Restore Open edX data
echo "Restoring Open edX data..."
docker volume rm docker_openedx_data || true
docker volume create docker_openedx_data
tar -xzf "$BACKUP_DIR/openedx_data.tar.gz" -C /var/lib/docker/volumes/

# Restore configuration if needed
if [ -f "$BACKUP_DIR/config.tar.gz" ]; then
  echo "Restoring configuration..."
  # Backup current configuration first
  mv ../docker/config ../docker/config.bak.$(date +%Y%m%d%H%M%S)
  mkdir -p ../docker/config
  tar -xzf "$BACKUP_DIR/config.tar.gz" -C ../docker/
fi

# Start services
echo "Starting services..."
docker-compose up -d

echo "Restore completed at $(date)"
