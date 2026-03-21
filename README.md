# Media Download Stack - ARR with Dual qBittorrent

A production-grade **self-hosted media stack** with full VPN protection and automated GitOps deployment. This setup features a unique **dual qBittorrent architecture** for optimal tracker reputation management.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      Docker Host (VPN Protected)                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐     ┌─────────────────────────────────────┐  │
│  │   VPN        │     │      Media Management Stack         │  │
│  │ (NordLynx)   │     │                                     │  │
│  └──────┬───────┘     │  ┌─────────────────────────────┐    │  │
│         │             │  │   Download Managers         │    │  │
│         │ network:    │  │  - throw_torrent (Temp)     │    │  │
│         ▼ service    │  │  - keep_torrent (Seeding)     │    │  │
│         │             │  └─────────────────────────────┘    │  │
│  ┌──────────────────┐│                                     │  │
│  │  throw_torrent   ││  ┌─────────────────────────────┐    │  │
│  │  (TEMP DOWNLOAD) ││  │   Content Managers          │    │  │
│  │                  ││  │  - Radarr (Movies)          │    │  │
│  └──────────────────┘│  │  - Sonarr (TV Shows)        │    │  │
│                      │  │  - Lidarr (Music)           │    │  │
│  ┌──────────────────┐│  └─────────────────────────────┘    │  │
│  │  keep_torrent    ││                                     │  │
│  │  (PERMANENT      ││  ┌─────────────────────────────┐    │  │
│  │   SEEDING)       ││  │   Utilities                 │    │  │
│  │                  ││  │  - Jackett (Indexers)       │    │  │
│  └──────────────────┘│  │  - Bazarr (Subtitles)       │    │  │
│                      │  │  - Flaresolverr (Anti-bot)  │    │  │
│  ┌──────────────────┐│  └─────────────────────────────┘    │  │
│  │  Radarr          ││                                     │  │
│  └──────────────────┘│  ┌─────────────────────────────┐    │  │
│                      │  │   Monitoring & Requests     │    │  │
│  ┌──────────────────┐│  │  - Overseerr (Requests)     │    │  │
│  │  Sonarr          ││  │  - Tautulli (Analytics)     │    │  │
│  └──────────────────┘│  └─────────────────────────────┘    │  │
│                      │                                     │  │
│  ┌──────────────────┐│  ┌─────────────────────────────┐    │  │
│  │  Lidarr          ││  │   P2P Networks              │    │  │
│  └──────────────────┘│  │  - Soularr (Auto-config)    │    │  │
│                      │  │  - slskd (Soulseek)         │    │  │
│  ┌──────────────────┐│  └─────────────────────────────┘    │  │
│  │  Bazarr          ││                                     │  │
│  └──────────────────┘└─────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                           │
                    Secure NordLynx Tunnel
                           │
                    Public Internet (VPN)
```

## 🎯 Dual qBittorrent Architecture

This stack uses **two separate qBittorrent instances** for optimal tracker reputation management:

### throw_torrent (Temporary Downloads)
- **Purpose**: Handle all new downloads requested by Radarr/Sonarr/Lidarr
- **Behavior**: Automatically removed after completion
- **Benefits**:
  - Clean seeding ratio for each release
  - No bandwidth wasted on old torrents
  - Fresh start for each download

### keep_torrent (Permanent Seeding)
- **Purpose**: Maintain long-term upload ratio and reputation
- **Behavior**: Keeps selected torrents forever
- **Benefits**:
  - Builds trust with private trackers
  - Improves upload ratio across all trackers
  - Better access to bonus content

**Workflow**: Download → Complete in throw_torrent → Move to keep_torrent for seeding

## 🚀 Quick Start

### Prerequisites
1. Docker Compose v2+ installed
2. NordVPN subscription (for VPN token)
3. Git repository with self-hosted runner (optional, for automated deployment)

### 1. Clone and Configure

```bash
# Clone repository
git clone https://github.com/nicolasnkGH/media-download.git
cd media-download

# Create environment file
cp .env.example .env

# Edit .env with your values:
nano .env
```

**Required variables in `.env`:**
```bash
VPN_TOKEN=your_real_nordvpn_token_here  # From nordvpn.com/account
PUID=1000                                # Your user ID (id -u)
PGID=1000                                # Your group ID (id -g)
TZ=America/New_York                      # Your timezone
```

### 2. Launch the Stack

```bash
# Start all services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### 3. Access Web Interfaces

After 30 seconds for services to initialize:

| Service | URL | Purpose |
|---------|-----|---------|
| Radarr | http://localhost:7878 | Movie manager |
| Sonarr | http://localhost:8989 | TV show manager |
| Lidarr | http://localhost:8686 | Music manager |
| Bazarr | http://localhost:6767 | Subtitle manager |
| Jackett | http://localhost:9117 | Indexer search bridge |
| Tautulli | http://localhost:8181 | Plex statistics |
| Overseerr | http://localhost:5055 | Content requests |
| throw_torrent | http://localhost:8090 | Temporary downloads |
| keep_torrent | http://localhost:8085 | Permanent seeding |

## 🔄 CI/CD Deployment

### Configure GitHub Secrets

In your repository, go to **Settings → Secrets → Actions** and add:

| Secret | Description |
|--------|-------------|
| `TARGET_HOST` | Your server's IP address |
| `TARGET_USERNAME` | SSH username (e.g., `root` or your user) |
| `TARGET_SSH_KEY` | Private SSH key for authentication |
| `VPN_TOKEN` | NordVPN token (auto-injected on deploy) |

### Deploy to Server

```bash
git commit -m "Update media stack configuration"
git push origin main
```

The deployment workflow will:
1. Copy updated `docker-compose.yml` to server
2. Generate `.env` from GitHub Secrets
3. Pull latest images
4. Restart services with force-recreate
5. Verify health checks
6. Report status

### Manual Deployment via API

```bash
curl -X POST \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/repos/nicolasnkGH/media-download/actions/workflows/deploy.yml/dispatches
```

## 📁 Volume Structure

```
media-download/
├── .env                        # Environment configuration (DO NOT COMMIT)
├── docker-compose.yml          # Main composition file
├── docker-compose.override.yml # Development port mappings
├── README.md                   # This file
│
├── config/                     # Service configurations
│   ├── radarr/
│   ├── sonarr/
│   ├── lidarr/
│   ├── bazarr/
│   ├── jackett/
│   ├── overseerr/
│   ├── tautulli/
│   ├── flaresolverr/
│   ├── soularr/
│   ├── slskd/
│   ├── throw_torrent/
│   └── keep_torrent/
│
└── data/                       # Media storage
    ├── movies/
    ├── tv/
    ├── music/
    ├── downloads/              # throw_torrent destination
    ├── seeding/                # keep_torrent source
    └── torrents/               # Jackett downloads
```

## 🔒 Security Features

### VPN Protection
- All services route through NordVPN via `network_mode: service:vpn`
- Uses NordLynx protocol for optimal performance
- IPv6 disabled to prevent leaks (`net.ipv6.conf.all.disable_ipv6=1`)

### Network Isolation
- No ports exposed from VPN container in production
- Custom network mode ensures traffic flows through VPN only
- Services cannot bypass VPN tunnel

### Secret Management
- `VPN_TOKEN` injected via GitHub Secrets at deployment time
- Never stored in codebase or committed to git
- Environment file generated dynamically on server

### File Permissions
- `PUID`/`PGID` configuration ensures proper ownership
- Containers run as your user, not root
- Prevents permission issues with mounted volumes

## 🛡️ Resource Optimization

| Service | Original Limit | Optimized Limit | Notes |
|---------|---------------|-----------------|-------|
| throw_torrent | 2g | 512m | Sufficient for download manager |
| keep_torrent | 2g | 512m | Same as above |
| radarr | 1g | 256m | Lightweight .NET app |
| sonarr | 1g | 256m | Mono/.NET app |
| lidarr | 512m | 256m | Music manager |
| jackett | 512m | 256m | Search bridge |
| bazarr | 512m | 256m | Subtitle manager |
| tautulli | 512m | 256m | Python monitoring |

## 🏥 Health Monitoring

All services include health checks:
- **Interval**: 60 seconds
- **Timeout**: 10 seconds
- **Retries**: 5

```bash
# Check health status
docker compose ps

# View specific service logs
docker compose logs -f radarr

# Force recreate if unhealthy
docker compose up -d --force-recreate
```

## 📊 Tautulli Configuration

1. Start Tautulli after other services are running
2. Add your Plex Media Server as a "Plex Media Server" connection:
   - **Name**: Plex
   - **Hostname**: plex (if on same network) or host-ip
   - **Port**: 32400
   - **API Key**: Get from Plex settings

Tautulli will then track all downloads made by Radarr/Sonarr and display statistics.

## 🎵 Soularr + slskd Configuration

### Soularr Setup
1. Access Soularr web UI (http://localhost:5055 if using override)
2. Add your Radarr, Sonarr API endpoints
3. Configure automation preferences

### slskd Setup
1. Access slskd web UI at http://localhost:5030
2. Create a Soulseek account or use anonymous mode
3. Configure share folders for music collection
4. Set download directory to match your music library

## 🚨 Troubleshooting

### Services Won't Start
```bash
# Check VPN connection
docker exec nord_vpn ping -c 1 www.google.com

# Restart VPN container
docker compose restart vpn

# Verify network connectivity between services
docker compose ps | grep healthy
```

### Torrent Download Fails
1. Check throw_torrent log for tracker response errors:
   ```bash
   docker logs throw_torrent | grep -i error
   ```
2. Ensure Jackett is configured with working indexers
3. Verify Flaresolverr is running (required by some trackers)

### Port Already in Use
```bash
# Kill existing process on port 7878
sudo lsof -ti:7878 | xargs sudo kill -9

# Or use docker-compose.override.yml for custom ports
```

## 📝 Roadmap

- [x] Dual qBittorrent architecture for seeding optimization
- [x] Full VPN protection for all services
- [x] GitHub Actions CI/CD deployment
- [x] Health checks on all critical services
- [x] Optimized resource limits
- [ ] Automatic torrent cleanup (remove completed from throw_torrent)
- [ ] Integration with RealDebrid/Premiumize for offloading seeding
- [ ] Docker volume backup automation
- [ ] Performance metrics dashboards

## ⚖️ Legal Disclaimer

This setup is intended for **personal use** and should only be used for downloading and streaming **legally acquired content**. By using these services, you agree to comply with all applicable laws and regulations in your jurisdiction.

The repository creator is not responsible for any illegal activities or misuse of the system. Users are encouraged to:
- Only download content they have legal rights to access
- Comply with local copyright laws
- Use private trackers ethically and according to their rules
- Maintain appropriate upload ratios on private tracker networks

## 📄 License

MIT License - See LICENSE file for details.

---

**Built with:** Docker Compose, GitHub Actions, NordVPN, Radarr, Sonarr, Lidarr, Jackett
