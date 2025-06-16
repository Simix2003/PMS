# PMS Backend

This folder contains the FastAPI backend for the Production Monitoring System.

## Environment variables

The application reads configuration from the following variables:

- `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_DB` – MySQL connection settings.
- `BASE_DIR` – directory used to store persistent data (models, images, settings...).
- `XML_FOLDER_PATH` – location of incoming XML files.
- `PUBLIC_BASE_URL` – public URL used when returning image paths.
- `DEBUG` – set to `true` to enable debug mode.

Defaults are provided so the app can run without setting them, but overriding
them is recommended for production deployments.

## Docker usage

Build and run the backend together with a MySQL database using Docker Compose:

```bash
cd service
docker compose up --build
```

The service will be exposed on port `8001` and MySQL on `3306`.
