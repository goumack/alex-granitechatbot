"""
Fix SQLite version for Chroma DB compatibility.
This must be imported BEFORE chromadb to replace the system SQLite.
"""
import sys

try:
    import pysqlite3
    sys.modules['sqlite3'] = pysqlite3
except ImportError:
    pass  # Fall back to system sqlite3

# Now we can import chromadb
import chromadb  # noqa
