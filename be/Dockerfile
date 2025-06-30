FROM python:3.11-slim

WORKDIR /app

# Copia i file di configurazione e requirements
COPY service/pyproject.toml service/service.spec ./
COPY service/requirements.txt ./


# Copia tutto il codice sorgente della service (inclusi controllers, ecc.)
COPY service/ ./service/


# Installa le dipendenze
RUN pip install --upgrade pip && \
    if [ -f requirements.txt ]; then pip install -r requirements.txt; fi

# (Opzionale) imposta il PYTHONPATH per evitare problemi di import
ENV PYTHONPATH=/app/service

RUN mkdir -p /app/images/
RUN mkdir -p /app/ix-monitor/
RUN mkdir -p /app/ix-monitor/images

EXPOSE 8001

WORKDIR /app/service

COPY wait-for-it.sh /wait-for-it.sh
RUN chmod +x /wait-for-it.sh
CMD ["/wait-for-it.sh", "pms-db:3306", "--", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]