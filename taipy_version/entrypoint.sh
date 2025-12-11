#!/bin/bash
# Script d'entrée pour remplacer sqlite3 avant de lancer l'app
export PYTHONPATH=/app:$PYTHONPATH
exec python -c "
import sys
try:
    import pysqlite3
    sys.modules['sqlite3'] = pysqlite3
except ImportError:
    pass
from app_taipy import app
app.run(host='0.0.0.0', port=8505, threaded=True)
"
