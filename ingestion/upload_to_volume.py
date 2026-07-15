import os
import sys
from pathlib import Path
from databricks.sdk import WorkspaceClient

# 1. Initialize the Databricks Client (automatically uses your .env variables)
DATABRICKS_HOST = os.environ.get("DATABRICKS_HOST")
DATABRICKS_TOKEN = os.environ.get("DATABRICKS_TOKEN")

if not DATABRICKS_HOST or not DATABRICKS_TOKEN:
    print("❌ Missing DATABRICKS_HOST or DATABRICKS_TOKEN environment variables.")
    sys.exit(1)

db_client = WorkspaceClient(
    host=DATABRICKS_HOST,
    token=DATABRICKS_TOKEN
)

# 2. Define our target path in Unity Catalog
# Format: /Volumes/<catalog>/<schema>/<volume_name>/
TARGET_VOLUME_PATH = "/Volumes/olist/bronze/raw_unstructured_files"

# Resolve relative to this script's location instead of hardcoding an absolute path
LOCAL_DATA_DIR = Path(__file__).resolve().parent / "data"


def upload_csv_files():
    print("🚀 Starting upload to Databricks Unity Catalog Volume...")

    if not LOCAL_DATA_DIR.exists():
        print(f"❌ Local data directory not found: {LOCAL_DATA_DIR}")
        return

    csv_files = list(LOCAL_DATA_DIR.glob("*.csv"))

    if not csv_files:
        print(f"❌ No CSV files found in {LOCAL_DATA_DIR}! Did you place them in the correct folder?")
        return

    succeeded = []
    failed = []

    for file_path in csv_files:
        remote_file_path = f"{TARGET_VOLUME_PATH}/{file_path.name}"
        print(f"📦 Uploading {file_path.name}...")

        try:
            with open(file_path, "rb") as f:
                db_client.files.upload(remote_file_path, f, overwrite=True)
            print(f"✅ Successfully uploaded: {file_path.name}")
            succeeded.append(file_path.name)
        except Exception as e:
            print(f"⚠️ Failed to upload {file_path.name}: {e}")
            failed.append(file_path.name)

    print(f"\n🎉 Done. {len(succeeded)} succeeded, {len(failed)} failed.")
    if failed:
        print(f"Failed files: {', '.join(failed)}")


if __name__ == "__main__":
    upload_csv_files()
