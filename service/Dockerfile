FROM python:3.11.2-slim

WORKDIR /app

# Install system-level build dependencies for ML/Py packages
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    build-essential \
    cmake \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Copy wheels and requirements.txt first (leverages Docker layer cache)
COPY wheels/ ./wheels/
COPY requirements.txt ./requirements.txt

# Install Python dependencies from wheels cache
RUN pip install --no-cache-dir --no-index --find-links=./wheels -r requirements.txt

# Copy the rest of the application
COPY . .

EXPOSE 8001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]