FROM python:3.10-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    libopencv-dev \
    python3-opencv \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create cache directory
RUN mkdir -p /opt/homix-cache/.insightface

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV INSIGHTFACE_HOME=/opt/homix-cache/.insightface
ENV HOME=/opt/homix-cache

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health', timeout=5)"

# Start application
CMD ["python", "app.py"]
