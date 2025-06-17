# PMS Backend

This folder contains the FastAPI backend for the **Production Monitoring System (PMS)**.

---

## 📁 Folder Contents

- `main.py` — Main application entry point
- `Dockerfile` — Optimized image build using wheel caching
- `docker-compose.yml` — Orchestrates backend and MySQL
- `requirements.txt` — Locked Python dependencies
- `.env` — Runtime configuration variables
- `wheels/` — Prebuilt Python wheels to speed up Docker builds

---

## ⚙️ Environment Variables

The app loads the following from `.env`:

| Variable | Description |
|----------|-------------|
| `BASE_DIR` | Root folder for images, models, temp files (in container: `/data`) |
| `MYSQL_HOST` | MySQL hostname (in Docker: `db`) |
| `MYSQL_PORT` | MySQL port (`3306`) |
| `MYSQL_USER` | MySQL username (`root`) |
| `MYSQL_PASSWORD` | MySQL password |
| `MYSQL_DB` | MySQL database name (`ix_monitor`) |

> These are automatically injected by `docker-compose.yml`.

---

## 🐳 Run with Docker Compose

Build and start PMS backend + MySQL:

```bash
cd D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor\service

#TO BUILD IT
docker compose up --build

# TO RUN IT
docker compose up


# We should have 1 Container for the Python Backend ( port 8001 )
# We should then have 1 Container for Frontend ( NGINX, Port 8050 to 8055 )