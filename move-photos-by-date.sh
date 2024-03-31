#!/bin/bash

# This script organizes images into directories based on their EXIF creation date.

# Initialize variables
TARGET_DIR=""
SOURCE_DIR=""
PATTERN=""
EXCLUDE_DIRS=""

# Define option string for getopts
OPTSTRING=":t:s:p:e:"

# Process input options
while getopts ${OPTSTRING} opt; do
  case ${opt} in
    t) # Target directory
      TARGET_DIR="${OPTARG}"
      ;;
    s) # Source directory
      SOURCE_DIR="${OPTARG}"
      ;;
    p) # Date pattern for organizing
      PATTERN="${OPTARG}"
      ;;
    e) # Directories to exclude from the search
      EXCLUDE_DIRS="${OPTARG}"
      ;;
    :) # Missing option argument
      echo "Option -${OPTARG} requires an argument."
      exit 1
      ;;
    ?) # Invalid option
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
  esac
done

# Check for required parameters and print usage if missing
if [ -z "${TARGET_DIR}" ] || [ -z "${SOURCE_DIR}" ] || [ -z "${PATTERN}" ] || [ $# -eq 0 ]; then
    echo "Usage: $0 -p <Pattern: y-m-d/y-m> -s <SourceDirectoryPath> -t <TargetDirectoryPath> [-e <ExcludeDirectories>]"
    exit 1
fi

# Ensure the pattern is correctly specified
if [[ $PATTERN != "y-m-d" && $PATTERN != "y-m" ]]; then
    echo "Error: The pattern must be either 'y-m-d' or 'y-m'."
    exit 2
fi

# Check for exiftool availability
if ! command -v exiftool &> /dev/null; then
    echo "Error: exiftool is not installed." >&2
    exit 1
fi

# Defines a function to process a single image file
process_file() {
    # Ensures a file path is provided
    if [ $# -eq 0 ]; then
        echo "Error: No file path provided."
        return 1
    fi
    local image=$1
    local image_base=$(basename "$image")
    local year month day

    # Extract EXIF creation date and organize based on the pattern
    if exiftool "$image" &> /dev/null; then
        read year month day <<< $(exiftool -d "%Y %m %d" -DateTimeOriginal "$image" | awk '/Date\/Time Original/ {print $4, $5, $6}')

        # Create target directory based on the pattern and move the image
        if [ "$PATTERN" = "y-m-d" ]; then
            local image_target="$TARGET_DIR/$year/$month/$day/$image_base"
            mkdir -p "$TARGET_DIR/$year/$month/$day"
        elif [ "$PATTERN" = "y-m" ]; then
            local image_target="$TARGET_DIR/$year/$month/$image_base"
            mkdir -p "$TARGET_DIR/$year/$month/"
        fi

        # Check for file existence and log accordingly
        if [ -f "$image_target" ]; then
            echo "# Exists in target: \"$image\"" >> $NOT_MOVE
        else
            echo "mv \"$image\" \"$image_target\"" >> $MOVEFILE
        fi
    else
        # Log unprocessable files
        echo "# Not an image: \"$image\"" >> "$NOT_MOVE"
    fi
}

# Initialize log files for actions
MOVEFILE=move.sh
NOT_MOVE=cannot_move.txt
echo -n "" > "$MOVEFILE"
chmod +x "$MOVEFILE"
echo -n "" > "$NOT_MOVE"

# Export variables and functions for subprocesses
export -f process_file
export TARGET_DIR
export SOURCE_DIR
export MOVEFILE
export NOT_MOVE
export PATTERN

# Construct find command's exclude string
EXCLUDE_STRING=""
if [ ! -z "$EXCLUDE_DIRS" ]; then
    IFS=',' read -ra ADDR <<< "$EXCLUDE_DIRS"
    for i in "${!ADDR[@]}"; do
        EXCLUDE_STRING="$EXCLUDE_STRING -o -name ${ADDR[i]}"
    done
    EXCLUDE_STRING="( $EXCLUDE_STRING ) -prune -o"
fi

# Validate source directory existence
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: The directory \"$SOURCE_DIR\" does not exist."
    exit 1
fi

# Optimize processing using available CPU cores
N_CORES=$(nproc)

# Use find and xargs to process files in parallel
find "$SOURCE_DIR" $EXCLUDE_STRING  -type f -print0 | xargs -0 -P "$N_CORES" -I {} bash -c 'process_file "$@"' _ {}

# Summarize and report the outcome
COUNT_FOUND=$(wc -l < "$MOVEFILE")
COUNT_NOT_FOUND=$(wc -l < "$NOT_MOVE")
echo "$COUNT_FOUND files found that can be moved."
echo "$COUNT_NOT_FOUND files found that cannot be moved."
