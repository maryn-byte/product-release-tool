FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Mutable data (SQLite database) lives here; mount a volume to persist it
VOLUME ["/data"]

# SQLite database URL — override with -e DATABASE_URL=sqlite:////your/path/db
ENV DATABASE_URL=sqlite:////data/planner.db

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
