#!/bin/bash
set -e

# Load environment variables
source ../docker/.env

DATE=$(date +%Y%m%d)
BACKUP_DIR="/backup/$DATE"
mkdir -p "$BACKUP_DIR"

echo "Starting backup at $(date)"

# Ensure backup directory exists and is writable
if [ ! -d "$BACKUP_DIR" ]; then
  echo "Creating backup directory: $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
fi

# Check for available disk space (require at least 5GB free)
FREE_SPACE=$(df -k "$BACKUP_DIR" | awk 'NR==2 {print $4}')
if [ "$FREE_SPACE" -lt 5242880 ]; then  # 5GB in KB
  echo "ERROR: Insufficient disk space. Only $(($FREE_SPACE/1024))MB available on backup volume."
  exit 1
fi

# Backup MySQL database
echo "Backing up MySQL database..."
docker exec mysql mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" --all-databases --single-transaction > "$BACKUP_DIR/mysql_dump.sql"

# Backup Open edX data directory
echo "Backing up Open edX data..."
cd ../docker
docker-compose stop lms cms
tar -czf "$BACKUP_DIR/openedx_data.tar.gz" -C /var/lib/docker/volumes/ docker_openedx_data
docker-compose start lms cms

# Backup Redis data
echo "Backing up Redis data..."
docker exec redis redis-cli save
tar -czf "$BACKUP_DIR/redis_data.tar.gz" -C /var/lib/docker/volumes/ docker_redis_data

# Backup configuration
echo "Backing up configuration..."
tar -czf "$BACKUP_DIR/config.tar.gz" -C ../docker config

# Create backup manifest
cat > "$BACKUP_DIR/backup_manifest.json" << EOF
{
  "backup_date": "$(date -Iseconds)",
  "backup_type": "full",
  "components": ["mysql", "openedx_data", "redis_data", "config"],
  "checksum": "$(find $BACKUP_DIR -type f -not -name "backup_manifest.json" -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)"
}
EOF

# Cleanup old backups (keep 7 days)
find /backup -maxdepth 1 -type d -name "20*" -mtime +7 -exec rm -rf {} \;

echo "Backup completed at $(date)"
echo "Backup stored in: $BACKUP_DIR"
