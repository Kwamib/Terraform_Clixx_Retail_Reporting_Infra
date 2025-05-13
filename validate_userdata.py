import re
import sys
import os

# Paths (adjust if needed)
main_tf_path = "main.tf"       # Your main Terraform file
userdata_path = "userdata.sh"  # Your User Data script

# Ensure both files exist
if not os.path.exists(main_tf_path):
    print("[ERROR]: 'main.tf' file not found.")
    sys.exit(1)

if not os.path.exists(userdata_path):
    print("[ERROR]: 'userdata.sh' file not found.")
    sys.exit(1)

# Load the main.tf file
with open(main_tf_path, "r") as file:
    main_tf_content = file.read()

# Regex to extract variables from templatefile
templatefile_pattern = re.compile(r'templatefile\([^)]+,\s*{([^}]+)}\)', re.DOTALL)
match = templatefile_pattern.search(main_tf_content)

if not match:
    print("[ERROR]: No templatefile block found in main.tf")
    sys.exit(1)

# Extract all variables passed to templatefile
variables_block = match.group(1)
passed_vars = re.findall(r'(\w+)\s*=', variables_block)
passed_vars = list(set(passed_vars))  # Remove duplicates

# Load userdata.sh content
with open(userdata_path, "r") as file:
    userdata_content = file.read()

# Check for unused variables
unused_vars = [var for var in passed_vars if not re.search(rf"\${{{var}}}", userdata_content)]

# Output Results
print("Variables passed to userdata.sh:", ", ".join(passed_vars))
if unused_vars:
    print(f"[ERROR]: The following variables are passed to userdata.sh but are NOT used: {', '.join(unused_vars)}")

    # Ask user if they want to auto-fix
    fix = input("Would you like me to automatically remove these unused variables from main.tf? (yes/no): ").strip().lower()
    if fix == "yes":
        # Remove unused variables from templatefile in main.tf
        for var in unused_vars:
            main_tf_content = re.sub(rf'\s*{var}\s*=\s*[^,]+,?\n?', '', main_tf_content)

        # Save the cleaned main.tf
        with open(main_tf_path, "w") as file:
            file.write(main_tf_content)

        print(f"[INFO]: Unused variables {', '.join(unused_vars)} have been removed from main.tf.")
    else:
        print("[INFO]: No changes were made.")

else:
    print("[INFO]: All variables are correctly used in userdata.sh")
