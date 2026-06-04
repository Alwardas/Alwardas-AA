import io
import re

target_file = r'c:\Alwardas-AA\frontend\lib\screens\dashboards\hod\hod_department_screen.dart'
scratch_file = r'c:\Alwardas-AA\frontend\lib\scratch_graduated.dart'

# Read as raw bytes to safely strip null bytes
with open(target_file, 'rb') as f:
    raw_bytes = f.read()
    
# Remove null bytes (UTF-16 artifacts)
clean_bytes = raw_bytes.replace(b'\x00', b'')

# Decode to string
content = clean_bytes.decode('utf-8', errors='ignore')

# We want to keep everything up to the end of HodSyllabusYearsScreen
# HodSyllabusYearsScreen is the last class before the corrupted part
# We can just look for the corrupted marker or the end of the file
# Let's find "// Scratch file to hold HodGraduatedStudentsScreen" and truncate there
idx = content.find("// Scratch file to hold HodGraduatedStudentsScreen")
if idx != -1:
    content = content[:idx]

# Read scratch content
with io.open(scratch_file, 'r', encoding='utf-8') as f:
    scratch_content = f.read()

# Write it back cleanly
with io.open(target_file, 'w', encoding='utf-8') as f:
    f.write(content.strip())
    f.write('\n\n')
    f.write(scratch_content)

print("File cleanly rebuilt.")
