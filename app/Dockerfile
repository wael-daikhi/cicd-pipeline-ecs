FROM python:3.12-slim

# Don't buffer stdout/stderr — logs appear in CloudWatch immediately
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Copy only the runtime requirements first (layer cache optimization)
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY app.py ./

# Run as a non-root user
RUN useradd --create-home appuser
USER appuser

EXPOSE 3000

# gunicorn: 2 workers, bind to the container port, serve the "app" object
CMD ["gunicorn", "--bind", "0.0.0.0:3000", "--workers", "2", "app:app"]