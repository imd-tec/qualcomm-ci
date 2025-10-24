#https://developers.google.com/workspace/drive/api/guides/manage-downloads?_gl=1*1e2prwn*_up*MQ..*_ga*NzAxMjcwNzM1LjE3NjA1MjU1MDA.*_ga_SM8HXJ53K2*czE3NjA1MjU0OTkkbzEkZzAkdDE3NjA1MjU0OTkkajYwJGwwJGgw
import io, sys, os, re, warnings
import google.auth
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError
from googleapiclient.http import MediaIoBaseDownload

# Suppress SSL resource warnings from Google API client
warnings.filterwarnings("ignore", category=ResourceWarning, message="unclosed.*ssl.SSLSocket.*")

SCOPES = ["https://www.googleapis.com/auth/drive.metadata.readonly",
"https://www.googleapis.com/auth/drive.readonly"]

def get_service():
    try:
        creds = Credentials.from_authorized_user_file("token.json", SCOPES)
    except FileNotFoundError:
        print("ERROR: token.json file not found.")
        sys.exit(1)
    return build("drive", "v3", credentials=creds)

def find_all_folders(service):
    """
    Get all folders in Google Drive.
    Returns a list of (folder_id, folder_name) tuples.
    """
    try:
        query = "mimeType='application/vnd.google-apps.folder'"
        results = service.files().list(q=query, 
                                       fields="files(id, name)",
                                       supportsAllDrives=True,
                                       includeItemsFromAllDrives=True
                                       ).execute()
        folders = results.get('files', [])
        return [(folder['id'], folder['name']) for folder in folders]
    except HttpError as error:
        print(f"An error occurred while searching for folders: {error}")
        return []


def find_corresponding_folder(service, filename):
    """
    Find folder matching expected name, regardless of whether it contains patches.
    Returns (folder_id, folder_name) or None.
    """
    print(f"\nSEARCHING FOR FOLDER MATCHING: '{filename}'")
    
    # Get all folders
    all_folders = find_all_folders(service)
    
    if not all_folders:
        print("Warning: No folders found in Google Drive")
        return None
    
    print(f"Found {len(all_folders)} folders to search.")
    
    # Try exact case-insensitive matching first
    print(f"Looking for exact match with: '{filename.lower()}'")
    for folder_id, folder_name in all_folders:
        if filename.lower() == folder_name.lower():
            print(f"Found exact case-insensitive match: '{filename}' -> '{folder_name}'")
            return (folder_id, folder_name)
    
    # Try partial matching (base name + version)
    base_name = filename
    version = ""
    
    # Extract version pattern
    version_match = re.search(r'[-_]?v?\d+\.\d+(\.\d+)?$', filename, re.IGNORECASE)
    if version_match:
        version = version_match.group()
        base_name = filename[:version_match.start()]
    
    # Try matching base name + version with different cases
    for folder_id, folder_name in all_folders:
        folder_base = folder_name
        folder_version = ""
        
        folder_version_match = re.search(r'[-_]?v?\d+\.\d+(\.\d+)?$', folder_name, re.IGNORECASE)
        if folder_version_match:
            folder_version = folder_version_match.group()
            folder_base = folder_name[:folder_version_match.start()]
        
        # Compare base names case-insensitively and versions
        if (base_name.lower() == folder_base.lower() and 
            version.lower() == folder_version.lower()):
            print(f"Found base+version match: '{filename}' -> '{folder_name}'")
            return (folder_id, folder_name)
    
    # Fallback hard-coded mappings
    prefix_mappings = {
        'imdt-qcom-bsp': 'QCS8550-SBC-BSP',
        # Add more mappings as needed
    }
    
    # Create case-insensitive lookup
    norm_prefix_map = {k.lower(): v for k, v in prefix_mappings.items()}

    # Split base and version (assumes format: base-vX.Y.Z)
    reg_match = re.match(r'^(?P<base>[A-Za-z0-9]+(?:[-_][A-Za-z0-9]+)*)(?P<version>[-_]v\d+(?:\.\d+)*)$',
                         filename, re.IGNORECASE)
    if reg_match:
        base = reg_match.group('base')
        version = reg_match.group('version')
        
        # Simple case-insensitive lookup
        for map_key, mapped_base in norm_prefix_map.items():
            if base.lower() == map_key:
                mapped_name = mapped_base + version
                print(f"Trying hard-coded mapping: '{filename}' -> '{mapped_name}'")
                
                # Check if mapped name exists in folders
                for folder_id, folder_name in all_folders:
                    if folder_name.lower() == mapped_name.lower():
                        print(f"Found folder via hard-coded mapping: '{mapped_name}'")
                        return (folder_id, folder_name)

    return None


def check_folder_has_patches(service, folder_id):
    """
    Check if specific folder contains patches.tar.gz.
    Returns patches_file_id or None.
    """
    try:
        query = f"name='patches.tar.gz' and '{folder_id}' in parents"
        results = service.files().list(q=query, 
                                       fields="files(id, name)",
                                       supportsAllDrives=True,
                                       includeItemsFromAllDrives=True
                                       ).execute()
        files = results.get('files', [])
        
        if files:
            return files[0]['id']  # Return the first matching file ID
        else:
            return None
    except HttpError as error:
        print(f"An error occurred while checking for patches: {error}")
        return None


def download_file(service, file_id, destination_path):
    """
    Download a file from Google Drive.
    """
    try:
        request = service.files().get_media(fileId=file_id)
        with open(destination_path, 'wb') as fh:
            downloader = MediaIoBaseDownload(fh, request)
            done = False
            while done is False:
                status, done = downloader.next_chunk()
                print(f"Download progress: {int(status.progress() * 100)}%")
        
        print(f"File downloaded successfully to: {destination_path}")
        return True
    except HttpError as error:
        print(f"An error occurred during download: {error}")
        return False

def list_patch_folders(service):
    """
    Get all folders that contain patches.tar.gz files.
    Returns list of (folder_id, folder_name, has_patches) tuples.
    """
    print("Searching for folders with patches.tar.gz files...")
    
    # Get ALL folders first (this was working before)
    all_folders = find_all_folders(service)
    if not all_folders:
        print("No folders found in Google Drive")
        return []
    
    print(f"Found {len(all_folders)} total folders. Checking for patches...")
    
    annotated = []
    folders_with_patches = 0
    
    for _, (folder_id, folder_name) in enumerate(all_folders, start=1):
        # Check if this folder contains patches.tar.gz
        has_patches = check_folder_has_patches(service, folder_id) is not None
        
        if has_patches:
            folders_with_patches += 1
            print(f"  {folders_with_patches}. {folder_name} : {folder_id}")
            annotated.append((folder_id, folder_name, True))
            
    print(f"\nFound {folders_with_patches} folders containing patches.tar.gz")
    return annotated

def main():
    """
    Two modes:
      - No args: list selectable patch folder options (interactive).
      - Two args: download patches for given <xml_filename> into <output_folder>.
    """
    # Validate args count
    if len(sys.argv) not in (1, 3):
        print("Usage:")
        print("  python download_patches.py           # list selectable patch folder options")
        print("  python download_patches.py <name> <output_folder>   # download patches for <name>")
        sys.exit(1)

    # Initialize Google Drive service once
    service = get_service()


    match len(sys.argv):
        case 1:
            # Mode 1: Interactive listing and selection
            if len(sys.argv) == 1:
                patch_folders = list_patch_folders(service)
                if not patch_folders:
                    print("No folders found.")
                    sys.exit(0)

                # Prompt selection
                try:
                    selection = input("Select folder to download patches from: ").strip()
                except (KeyboardInterrupt, EOFError):
                    print()
                    sys.exit(0)
                
                if not selection.isdigit() or int(selection) < 1 or int(selection) > len(patch_folders):
                    print("Invalid selection.")
                    sys.exit(1)

                _, fname, has_patches = patch_folders[int(selection) - 1]
                if not has_patches:
                    print(f"Folder '{fname}' does not contain patches.tar.gz.")
                    sys.exit(0)

                out = input("Enter output folder path to save patches (default: current directory): ").strip()
                output_folder = out if out else os.getcwd()
        case 3:
            # Mode 2: Non-interactive download given filename and output folder
            filename = sys.argv[1]
            output_folder = sys.argv[2]

            folder_info = find_corresponding_folder(service, filename)
            if not folder_info:
                print(f"ERROR: No corresponding folder found for '{filename}'")
                sys.exit(1)

            folder_id, folder_name = folder_info
            print(f"Found folder: '{folder_name}' (ID: {folder_id})")

            patches_file_id = check_folder_has_patches(service, folder_id)
            if not patches_file_id:
                print(f"INFO: Folder '{folder_name}' found but no patches.tar.gz available")
                sys.exit(0)
        case _:
            print("Invalid number of arguments.")   
            sys.exit(1)

    os.makedirs(output_folder, exist_ok=True)
    destination_path = os.path.join(output_folder, "patches.tar.gz")
    success = download_file(service, patches_file_id, destination_path)
    if success:
        print(f"SUCCESS: Patches downloaded to {destination_path}")
        sys.exit(0)
    else:
        print("ERROR: Download failed.")
        sys.exit(1)


if __name__ == "__main__":
    main()