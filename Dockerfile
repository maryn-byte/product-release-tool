FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# SQLite database URL — override with -e DATABASE_URL=sqlite:////your/path/db
ENV DATABASE_URL=sqlite:////data/planner.db
ENV APP_BASE_PATH=/project-planner

EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
## Local Prod-Like
# docker build -t project-planner .
# docker run -p 5000:5000 -v planner-data:/data project-planner
