# Open edX Single Instance Deployment

This project provides a basic solution for deploying Open edX using Docker containers on a single VM.

## Overview

This deployment includes:
- Open edX LMS (Learning Management System)
- Open edX Studio (CMS)
- MySQL database for persistent storage
- Redis for caching and sessions
- Caddy for SSL/TLS and reverse proxy
- Watchtower for automatic updates
- Backup and health check scripts

## Requirements

- Ubuntu 20.04 or newer
- 8GB RAM minimum (16GB recommended)
- 50GB storage minimum
- Docker and Docker Compose installed

> Note: You can rent a [ThreeFold Full VM](https://manual.grid.tf/documentation/dashboard/solutions/fullVm.html) on the Dashboard with IPv4 network.

## Installation

### Server Setup

1. **Update and install dependencies**:
   ```bash
   apt update
   apt install -y docker.io docker-compose git curl jq nano
   ```

2. **Create a user for Open edX**:
   ```bash
   adduser openedx
   usermod -aG docker openedx
   usermod -aG sudo openedx
   ```

3. **Set up the directory structure**:
   ```bash
   su - openedx
   mkdir -p openedx/docker/config/caddy
   mkdir -p openedx/docker/config/lms
   mkdir -p openedx/scripts
   mkdir -p /backup
   chown -R openedx:openedx /backup
   ```

### Deploy Open edX

1. **Clone or download this repository**:
   ```bash
   git clone https://github.com/mik-tf/openedx-vm
   cd openedx-vm
   ```

2. **Configure the environment**:
   ```bash
   cp docker/.env.example docker/.env
   # Edit .env with your domain and credentials
   nano docker/.env
   ```

3. **Start the containers**:
   ```bash
   cd docker
   docker-compose up -d
   ```

4. **Configure DNS**:
   Add DNS A records for your domain and studio subdomain pointing to your VM's IP address:
   - `yourdomain.com` → Your VM's IP
   - `studio.yourdomain.com` → Your VM's IP

5. **Set up cron jobs for maintenance**:
   ```bash
   # Add daily backup job
   (crontab -l 2>/dev/null; echo "0 2 * * * cd /home/openedx/openedx/scripts && ./backup.sh") | crontab -

   # Add health check job
   (crontab -l 2>/dev/null; echo "*/5 * * * * cd /home/openedx/openedx/scripts && ./health-check.sh") | crontab -
   ```

## Administration

### Creating Admin User

To create an admin user:

```bash
docker exec -it lms bash -c "python /openedx/edx-platform/manage.py lms --settings=tutor.production createsuperuser"
```

Follow the prompts to create your admin username, email, and password.

### Accessing Admin Panel

1. Log in to your Open edX site: `https://yourdomain.com/login`
2. Access the admin panel: `https://yourdomain.com/admin`

### Course Creation

1. Log in to Studio: `https://studio.yourdomain.com`
2. Click "New Course" to create your first course

## Maintenance

### Backups

Backups are automatically performed daily. To manually run a backup:

```bash
cd /home/openedx/openedx/scripts
./backup.sh
```

Backups are stored in `/backup/YYYYMMDD/` directories.

### Restore from Backup

To restore your system from a backup:

```bash
cd /home/openedx/openedx/scripts
./restore.sh /backup/YYYYMMDD
```

### Updates

Watchtower automatically checks for updates daily. To force an update:

```bash
docker restart watchtower
```

To manually update:

```bash
cd /home/openedx/openedx/docker
docker-compose pull
docker-compose up -d
```

## Troubleshooting

### Check Container Status

```bash
docker ps
# or
docker-compose ps
```

### View Container Logs

```bash
# LMS logs
docker logs lms

# CMS logs
docker logs cms

# Database logs
docker logs mysql

# Caddy logs
docker logs caddy
```

### Restart Services

```bash
cd /home/openedx/openedx/docker
docker-compose restart
```

Or restart a specific service:

```bash
docker-compose restart lms
```

### Common Issues

1. **SSL Certificate Problems**:
   - Ensure your domain is correctly pointing to your server
   - Check Caddy logs: `docker logs caddy`

2. **Database Connection Errors**:
   - Verify the MySQL service is running: `docker ps | grep mysql`
   - Check MySQL logs: `docker logs mysql`

3. **Out of Memory Errors**:
   - Increase your server's RAM or add swap space
   - Check memory usage: `free -h`

4. **Disk Space Issues**:
   - Check disk usage: `df -h`
   - Clean up old backups: `find /backup -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;`

## Security Notes

1. **Firewall**: Configure a firewall to only allow ports 22, 80, and 443:
   ```bash
   ufw allow 22/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw enable
   ```

2. **Updates**: Keep your host system updated:
   ```bash
   apt update && apt upgrade -y
   ```

3. **SSL/TLS**: Caddy automatically configures HTTPS with proper settings.

4. **Backups**: Consider copying backups to an off-site location periodically.
