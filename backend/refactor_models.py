import os
import re

backend_src = r"c:\Alwardas-AA\backend\src"
mod_path = os.path.join(backend_src, "models", "mod.rs")

with open(mod_path, 'r', encoding='utf-8') as f:
    mod_content = f.read()

# We want to extract the AppState and helper functions, and move all remaining structs to common.rs
# Actually, the safest way is to rename mod_path to common.rs, then rewrite mod.rs to export everything.

common_path = os.path.join(backend_src, "models", "common.rs")
with open(common_path, 'w', encoding='utf-8') as f:
    f.write(mod_content)

mod_rs_content = """pub mod auth;
pub mod user;
pub mod common;

pub use auth::*;
pub use user::*;
pub use common::*;
"""

with open(mod_path, 'w', encoding='utf-8') as f:
    f.write(mod_rs_content)

print("Refactored successfully")
