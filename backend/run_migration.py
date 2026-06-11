import pg8000.dbapi
import re
from urllib.parse import unquote
import ssl

db_url = "postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require"

# Parse URL
pattern = re.compile(r"postgresql://(?P<user>[^:]+):(?P<password>[^@]+)@(?P<host>[^:/]+)(:(?P<port>\d+))?/(?P<database>[^?\s]+)")
match = pattern.match(db_url)
if not match:
    raise ValueError("Invalid DATABASE_URL format")

gd = match.groupdict()
user = gd["user"]
password = unquote(gd["password"])
host = gd["host"]
port = int(gd["port"]) if gd["port"] else 5432
database = gd["database"]

print(f"Connecting to {host}:{port}/{database} as {user}...")

ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_NONE

conn = pg8000.dbapi.connect(
    user=user,
    password=password,
    host=host,
    port=port,
    database=database,
    ssl_context=ssl_context
)

cursor = conn.cursor()

print("Dropping old chat tables if they exist...")
drop_sql = """
DROP TABLE IF EXISTS chat_blocks;
DROP TABLE IF EXISTS chat_messages;
DROP TABLE IF EXISTS chat_group_members;
DROP TABLE IF EXISTS chat_groups;
DROP TABLE IF EXISTS chat_requests;
"""
cursor.execute(drop_sql)

# Read migration file
with open("migrations/20260611180000_create_chat_tables.sql", "r") as f:
    sql = f.read()

print("Executing SQL migration script...")
cursor.execute(sql)
conn.commit()
print("SQL Migration completed successfully!")
conn.close()
