"""
Project Planner — Flask + SQLite backend
Run: python app.py
"""

import json
import sqlite3
import os
from flask import Flask, jsonify, request, render_template, g

app = Flask(__name__)
DATABASE = os.path.join(os.path.dirname(__file__), 'planner.db')
SCHEMA_VERSION = 48

# ── Database helpers ──────────────────────────────────────────────────────────

def get_db():
    """Return a per-request database connection."""
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA journal_mode=WAL")   # safe concurrent reads
        db.execute("PRAGMA foreign_keys=ON")
    return db

@app.teardown_appcontext
def close_db(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def init_db():
    """Create tables and seed default state if the DB is empty."""
    db = sqlite3.connect(DATABASE)
    db.execute("PRAGMA journal_mode=WAL")

    db.executescript("""
        CREATE TABLE IF NOT EXISTS app_state (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS releases (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            position      INTEGER NOT NULL DEFAULT 0,
            name          TEXT    NOT NULL DEFAULT 'New Project',
            kanban_col    TEXT    NOT NULL DEFAULT 'Idea',
            bar_state     TEXT    NOT NULL DEFAULT '[]',
            milestone_state TEXT  NOT NULL DEFAULT '[]',
            engineers     TEXT    NOT NULL DEFAULT '[]',
            designer      TEXT    NOT NULL DEFAULT '',
            needs_data_eng INTEGER NOT NULL DEFAULT 0,
            needs_bi_analyst INTEGER NOT NULL DEFAULT 0,
            users         TEXT    NOT NULL DEFAULT '[]'
        );
    """)

    # Seed if empty
    count = db.execute("SELECT COUNT(*) FROM releases").fetchone()[0]
    if count == 0:
        _seed_default_data(db)

    db.commit()
    db.close()

def _default_bars():
    return json.dumps([
        {"isGroup": True, "subBars": [{"startWeek": 1, "endWeek": 2}, {"startWeek": 3, "endWeek": 4}]},
        {"isGroup": True, "subBars": [{"startWeek": 1, "endWeek": 2}, {"startWeek": 3, "endWeek": 4}, {"startWeek": 5, "endWeek": 6}]},
        {"isGroup": True, "subBars": [{"startWeek": 5, "endWeek": 6}, {"startWeek": 7, "endWeek": 9}, {"startWeek": 10, "endWeek": 11}]},
        {"isGroup": True, "subBars": [{"startWeek": 7, "endWeek": 7}, {"startWeek": 8, "endWeek": 11}, {"startWeek": 12, "endWeek": 12}, {"startWeek": 13, "endWeek": 13}]},
        {"isGroup": True, "subBars": [{"startWeek": 8, "endWeek": 10}, {"startWeek": 11, "endWeek": 12}, {"startWeek": 13, "endWeek": 13}]}
    ])

def _default_milestones():
    return json.dumps([
        {"week": 4}, {"week": 6}, {"week": 11}, {"week": 13},
        {"week": 9}, {"week": 12}, {"week": 10}, {"week": 14},
        {"week": 1}, {"week": 7}, {"week": 5}
    ])

def _early_bars():
    def d(s, e): return {"startWeek": s, "endWeek": e}
    return json.dumps([
        {"isGroup": True, "subBars": [d(1,1), d(1,1)]},
        {"isGroup": True, "subBars": [d(1,1), d(1,1), d(1,1)]},
        {"isGroup": True, "subBars": [d(1,1), d(1,1), d(1,2)]},
        {"isGroup": True, "subBars": [d(1,1), d(1,2), d(3,3), d(4,4)]},
        {"isGroup": True, "subBars": [d(1,1), d(2,3), d(4,4)]}
    ])

def _early_milestones():
    return json.dumps([
        {"week": -1}, {"week": -1}, {"week": 2}, {"week": 4},
        {"week": -1}, {"week": 3}, {"week": 1}, {"week": 5},
        {"week": -1}, {"week": -1}, {"week": -1}
    ])

def _mid_bars():
    def d(s, e): return {"startWeek": s, "endWeek": e}
    return json.dumps([
        {"isGroup": True, "subBars": [d(1,1), d(1,1)]},
        {"isGroup": True, "subBars": [d(1,1), d(1,2), d(3,4)]},
        {"isGroup": True, "subBars": [d(1,2), d(3,5), d(6,7)]},
        {"isGroup": True, "subBars": [d(3,3), d(4,7), d(8,8), d(9,9)]},
        {"isGroup": True, "subBars": [d(4,6), d(7,8), d(9,9)]}
    ])

def _mid_milestones():
    return json.dumps([
        {"week": -1}, {"week": 2}, {"week": 7}, {"week": 9},
        {"week": 5}, {"week": 8}, {"week": 6}, {"week": 10},
        {"week": -1}, {"week": 3}, {"week": 1}
    ])

def _late_bars():
    def d(s, e): return {"startWeek": s, "endWeek": e}
    return json.dumps([
        {"isGroup": True, "subBars": [d(5,6), d(7,8)]},
        {"isGroup": True, "subBars": [d(7,8), d(9,10), d(11,12)]},
        {"isGroup": True, "subBars": [d(9,10), d(11,13), d(14,15)]},
        {"isGroup": True, "subBars": [d(11,11), d(12,15), d(16,16), d(17,17)]},
        {"isGroup": True, "subBars": [d(12,14), d(15,16), d(17,17)]}
    ])

def _late_milestones():
    return json.dumps([
        {"week": 8}, {"week": 10}, {"week": 15}, {"week": 17},
        {"week": 13}, {"week": 16}, {"week": 14}, {"week": 18},
        {"week": 7}, {"week": 11}, {"week": 9}
    ])

SEED_DATA = [
    # (name, kanban_col, bars_fn, ms_fn, engineers, designer, data_eng, bi, users)
    ("Plaid Connections Issues",                    "In Build",  _early_bars, _early_milestones, [],              "",       False, False, []),
    ("Core Data Quality Strengthening",             "In QA",     _early_bars, _early_milestones, ["Tim","Brian"], "",       False, False, ["Engineering"]),
    ("Resource Management",                         "In QA",     _early_bars, _early_milestones, ["Tim"],         "Maria",  False, False, ["Creator Accountants","Historical Cleanup","Tax","Payroll","Customer Success","Sales"]),
    ("Employee Work Queue",                         "In QA",     _early_bars, _early_milestones, ["Anton"],       "Maria",  False, False, ["Creator Accountants","Historical Cleanup","Tax","Payroll","Customer Success","Sales"]),
    ("Tight V6 Adoption",                           "In QA",     _early_bars, _early_milestones, ["Anton"],       "",       False, False, ["Engineering"]),
    ("Bookkeeper Super View",                       "In QA",     _early_bars, _early_milestones, ["Anton"],       "Maria",  False, False, ["Historical Cleanup","Creator Accountants"]),
    ("Onboarding Architecture Refactor",            "In QA",     _early_bars, _early_milestones, ["David"],       "",       False, False, ["Engineering"]),
    ("Onboarding Workflows Dashboard",              "Deferred",  _early_bars, _early_milestones, ["David"],       "Farhan", False, False, []),
    ("Social OAuth",                                "In QA",     _early_bars, _early_milestones, ["Kevin","Jason"],"",      True,  False, ["Data"]),
    ("MVP: Activate Affiliates",                    "In QA",     _early_bars, _early_milestones, ["David"],       "",       False, False, ["Marketing","Customers"]),
    ("Customer Dashboard",                          "Deferred",  _early_bars, _early_milestones, [],              "",       False, False, []),
    ("Data Warehouse — HubSpot Emails(+) Store",   "Complete",  _early_bars, _early_milestones, [],              "",       True,  False, ["Data"]),
    ("Data Warehouse — Tight Data Store",          "Complete",  _early_bars, _early_milestones, [],              "",       True,  False, ["Data"]),
    ("Client Health Dashboard",                    "Complete",  _early_bars, _early_milestones, [],              "",       False, True,  ["Managers"]),
    ("Address NWRA Agent Issues",                  "Tech Debt", _early_bars, _early_milestones, [],              "",       False, False, []),
    ("Gusto Embedded",                             "Scoped",    _mid_bars,   _mid_milestones,   [],              "",       False, False, ["Payroll","Customers"]),
    ("Tax Recommendation Engine",                  "Scoped",    _mid_bars,   _mid_milestones,   [],              "",       False, False, ["Tax","Customers"]),
    ("Data Cleanup",                               "Tech Debt", _mid_bars,   _mid_milestones,   [],              "",       False, False, ["Data","Engineering"]),
    ("Ticketing / Comms",                          "Idea",      _default_bars, _default_milestones, [],          "",       False, False, ["Creator Accountants","Historical Cleanup","Payroll","Tax","Customers"]),
    ("Customer Product Management",                "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
    ("Cancellations",                              "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
    ("Delinquency",                                "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
    ("Optimized Navigation Project",               "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
    ("Centralized Doc Center",                     "Idea",      _default_bars, _default_milestones, [],          "",       False, False, ["Creator Accountants","Historical Cleanup","Payroll","Tax","Customers"]),
    ("Self Serve Sign Up",                         "Idea",      _late_bars,  _late_milestones,   [],              "",       False, False, ["Customers"]),
    ("Creator Financial IQ",                       "Deferred",  _late_bars,  _late_milestones,   [],              "",       False, False, ["Customers"]),
    ("AI P&L Checker",                             "Deferred",  _default_bars, _default_milestones, [],          "",       False, False, []),
    ("Affiliate Program Overhaul",                 "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
    ("Internal AI Assistant",                      "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
    ("CJAR Comms",                                 "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
    ("Design System Remediation",                  "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
    ("Resource Library",                           "Idea",      _default_bars, _default_milestones, [],          "",       False, False, []),
]

def _seed_default_data(db):
    db.execute("INSERT OR REPLACE INTO app_state VALUES ('cycle_start_date', '2026-05-11')")
    for pos, row in enumerate(SEED_DATA):
        name, kanban, bars_fn, ms_fn, engineers, designer, data_eng, bi, users = row
        db.execute("""
            INSERT INTO releases
              (position, name, kanban_col, bar_state, milestone_state,
               engineers, designer, needs_data_eng, needs_bi_analyst, users)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            pos, name, kanban,
            bars_fn(), ms_fn(),
            json.dumps(engineers), designer,
            1 if data_eng else 0, 1 if bi else 0,
            json.dumps(users)
        ))


# ── Helper: serialise a DB row to dict ────────────────────────────────────────

def row_to_dict(row):
    return {
        "id":              row["id"],
        "position":        row["position"],
        "name":            row["name"],
        "kanban_col":      row["kanban_col"],
        "bar_state":       json.loads(row["bar_state"]),
        "milestone_state": json.loads(row["milestone_state"]),
        "engineers":       json.loads(row["engineers"]),
        "designer":        row["designer"],
        "needs_data_eng":  bool(row["needs_data_eng"]),
        "needs_bi_analyst":bool(row["needs_bi_analyst"]),
        "users":           json.loads(row["users"]),
    }


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/project-planner")
def index():
    return render_template("index.html")


# GET  /api/state  — return full app state
@app.route("/project-planner/api/state", methods=["GET"])
def get_state():
    db = get_db()
    cycle_start = db.execute(
        "SELECT value FROM app_state WHERE key='cycle_start_date'"
    ).fetchone()
    releases = db.execute(
        "SELECT * FROM releases ORDER BY position ASC"
    ).fetchall()
    return jsonify({
        "cycle_start_date": cycle_start["value"] if cycle_start else "",
        "releases": [row_to_dict(r) for r in releases],
        "schema_version": SCHEMA_VERSION,
    })


# PUT  /api/state/date  — update cycle start date
@app.route("/project-planner/api/state/date", methods=["PUT"])
def set_date():
    data = request.get_json()
    db = get_db()
    db.execute(
        "INSERT OR REPLACE INTO app_state VALUES ('cycle_start_date', ?)",
        (data.get("cycle_start_date", ""),)
    )
    db.commit()
    return jsonify({"ok": True})


# PUT  /api/releases/<id>  — update a single release (any fields)
@app.route("/project-planner/api/releases/<int:release_id>", methods=["PUT"])
def update_release(release_id):
    data = request.get_json()
    db = get_db()
    fields, values = [], []

    field_map = {
        "name":             ("name",             lambda v: v),
        "kanban_col":       ("kanban_col",        lambda v: v),
        "bar_state":        ("bar_state",         json.dumps),
        "milestone_state":  ("milestone_state",   json.dumps),
        "engineers":        ("engineers",         json.dumps),
        "designer":         ("designer",          lambda v: v),
        "needs_data_eng":   ("needs_data_eng",    lambda v: 1 if v else 0),
        "needs_bi_analyst": ("needs_bi_analyst",  lambda v: 1 if v else 0),
        "users":            ("users",             json.dumps),
    }
    for key, (col, transform) in field_map.items():
        if key in data:
            fields.append(f"{col} = ?")
            values.append(transform(data[key]))

    if not fields:
        return jsonify({"ok": True})  # nothing to do

    values.append(release_id)
    db.execute(f"UPDATE releases SET {', '.join(fields)} WHERE id = ?", values)
    db.commit()
    return jsonify({"ok": True})


# POST /api/releases  — insert a new release at a given position
@app.route("/project-planner/api/releases", methods=["POST"])
def add_release():
    data = request.get_json()
    position = data.get("position", 9999)
    db = get_db()
    # Shift existing rows down to make room
    db.execute("UPDATE releases SET position = position + 1 WHERE position >= ?", (position,))
    cursor = db.execute("""
        INSERT INTO releases (position, name, kanban_col, bar_state, milestone_state,
                              engineers, designer, needs_data_eng, needs_bi_analyst, users)
        VALUES (?, ?, 'Idea', ?, ?, '[]', '', 0, 0, '[]')
    """, (position, data.get("name", "New Project"), _default_bars(), _default_milestones()))
    db.commit()
    row = db.execute("SELECT * FROM releases WHERE id = ?", (cursor.lastrowid,)).fetchone()
    return jsonify(row_to_dict(row)), 201


# DELETE /api/releases/<id>  — remove a release
@app.route("/project-planner/api/releases/<int:release_id>", methods=["DELETE"])
def delete_release(release_id):
    db = get_db()
    row = db.execute("SELECT position FROM releases WHERE id = ?", (release_id,)).fetchone()
    if row:
        db.execute("DELETE FROM releases WHERE id = ?", (release_id,))
        db.execute("UPDATE releases SET position = position - 1 WHERE position > ?", (row["position"],))
        db.commit()
    return jsonify({"ok": True})


# POST /api/releases/reorder  — update positions for all releases
@app.route("/project-planner/api/releases/reorder", methods=["POST"])
def reorder_releases():
    """Body: { "order": [id, id, id, ...] }"""
    data = request.get_json()
    order = data.get("order", [])
    db = get_db()
    for pos, release_id in enumerate(order):
        db.execute("UPDATE releases SET position = ? WHERE id = ?", (pos, release_id))
    db.commit()
    return jsonify({"ok": True})


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    init_db()
    app.run(debug=True, port=5000)
