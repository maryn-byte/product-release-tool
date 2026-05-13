# Project Planner — Deployment Guide

## What's in here

```
app.py               — Flask backend + SQLite database layer
requirements.txt     — Python dependencies (just Flask)
templates/
  index.html         — The full frontend (served by Flask)
planner.db           — Created automatically on first run
```

## Local development

```bash
# 1. Create and activate a virtual environment
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Run the dev server
python app.py
# → Open http://localhost:5000
```

The SQLite database (`planner.db`) is created automatically on first run
and seeded with the default project list. All changes made in the browser
are saved immediately to the database.

---

## Deploying to a server (e.g. Ubuntu VPS / DigitalOcean)

### Option A — Gunicorn + Nginx (recommended for production)

```bash
# Install gunicorn
pip install gunicorn

# Run with gunicorn (4 workers, port 8000)
gunicorn -w 4 -b 0.0.0.0:8000 app:app
```

Then point Nginx at port 8000:

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Option B — Railway / Render / Fly.io (one-click PaaS)

Add a `Procfile`:
```
web: gunicorn -w 2 -b 0.0.0.0:$PORT app:app
```

Then deploy via their CLI or GitHub integration. Set the working directory
to the folder containing `app.py`.

**Note on SQLite for multi-user:** SQLite with WAL mode handles light
concurrent traffic well (tens of simultaneous users). For heavier load,
ask your data engineer to swap the `sqlite3` calls in `app.py` for
`psycopg2` (PostgreSQL) — the API endpoints don't need to change.

---

## API reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET  | `/api/state` | Full app state (all releases + date) |
| PUT  | `/api/state/date` | Update cycle start date |
| PUT  | `/api/releases/<id>` | Update any fields on a release |
| POST | `/api/releases` | Insert a new release at a position |
| DELETE | `/api/releases/<id>` | Delete a release |
| POST | `/api/releases/reorder` | Update sort order for all releases |

---

## Database schema

```sql
app_state (key TEXT PRIMARY KEY, value TEXT)
releases  (id, position, name, kanban_col, bar_state, milestone_state,
           engineers, designer, needs_data_eng, needs_bi_analyst, users)
```

`bar_state`, `milestone_state`, `engineers`, and `users` are stored as
JSON strings. `needs_data_eng` and `needs_bi_analyst` are 0/1 integers.
