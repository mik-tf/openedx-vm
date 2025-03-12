#!/bin/bash

# Load environment variables
source ../docker/.env

LOG_FILE="/home/openedx/health-checks.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$DATE] Running health check" >> $LOG_FILE

# Check MySQL
if ! docker exec mysql mysqladmin ping -h localhost -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent; then
  echo "[$DATE] MySQL is down, restarting..." >> $LOG_FILE
  docker restart mysql
  sleep 10
fi

# Check Redis
if ! docker exec redis redis-cli ping | grep -q "PONG"; then
  echo "[$DATE] Redis is down, restarting..." >> $LOG_FILE
  docker restart redis
  sleep 5
fi

# Check LMS
if ! curl -sf http://localhost:8000/heartbeat > /dev/null; then
  echo "[$DATE] LMS is down, restarting..." >> $LOG_FILE
  docker restart lms
  sleep 20
fi

# Check CMS
if ! curl -sf http://localhost:8001/heartbeat > /dev/null; then
  echo "[$DATE] CMS is down, restarting..." >> $LOG_FILE
  docker restart cms
  sleep 20
fi

# Check Caddy
if ! curl -sf http://localhost:80/health > /dev/null; then
  echo "[$DATE] Caddy is down, restarting..." >> $LOG_FILE
  docker restart caddy
fi

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$DISK_USAGE" -gt 85 ]; then
  echo "[$DATE] WARNING: Disk usage is high: ${DISK_USAGE}%" >> $LOG_FILE

  # Clean up Docker if space is critical
  if [ "$DISK_USAGE" -gt 95 ]; then
    echo "[$DATE] Cleaning up Docker system to free space" >> $LOG_FILE
    docker system prune -f
  fi
fi

echo "[$DATE] Health check completed" >> $LOG_FILE
