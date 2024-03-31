#!/bin/bash

# This script organizes images into directories based on their EXIF creation date.

# Initialize variables
TARGET_DIR=""
SOURCE_DIR=""
PATTERN=""

OPTSTRING=":t:s:p:"

# Check if no options were provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 -p <Pattern: y-m-d/y-m> -s <SourceDirectoryPath> -t <TargetDirectoryPath>"
    echo "Example: $0 -p y-m-d -s /path/to/source -t /path/to/target"
    exit 1
fi

while getopts ${OPTSTRING} opt; do
  case ${opt} in
    t)
      TARGET_DIR="${OPTARG}"
      ;;
    s)
      SOURCE_DIR="${OPTARG}"
      ;;
    p)
      PATTERN="${OPTARG}"
      ;;
    :)
      echo "Option -${OPTARG} requires an argument."
      exit 1
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 1
      ;;
  esac
done

# Validate required parameters
if [ -z "${TARGET_DIR}" ] || [ -z "${SOURCE_DIR}" ] || [ -z "${PATTERN}" ]; then
    echo "Error: All options -t (target directory), -s (source directory), and -p (pattern) are required."
    exit 1
fi

# Validate the pattern
if [[ $PATTERN != "y-m-d" && $PATTERN != "y-m" ]]; then
    echo "Error: The pattern must be either '-p y-m-d' or '-p y-m'."
    exit 2
fi

# Checks if exiftool is installed on the system
if ! command -v exiftool &> /dev/null
then
    echo "Error: exiftool is not installed." >&2
    exit 1
fi

# Function to process a single file
process_file() {
    # Verifies that a file path argument is provided
    if [ $# -eq 0 ]; then
        echo "Error: No file path provided."
        return 1
    fi
    local image=$1
    local image_base=$(basename "$image")
    local year month day

    # Attempts to process the image with exiftool
    if exiftool "$image" &> /dev/null; then
        # Extracts the year, month, and day from the image's EXIF data
        read year month day <<< $(exiftool -d "%Y %m %d" -DateTimeOriginal "$image" | awk '/Date\/Time Original/ {print $4, $5, $6}')

        # Constructs the target path based on the specified pattern and create dir
        if [ "$PATTERN" = "y-m-d" ]; then
            local image_target="$TARGET_DIR/$year/$month/$day/$image_base"
            mkdir -p "$TARGET_DIR/$year/$month/$day"
        elif [ "$PATTERN" = "y-m" ]; then
            local image_target="$TARGET_DIR/$year/$month/$image_base"
            mkdir -p "$TARGET_DIR/$year/$month/"
        fi

        # Checks if the file already exists in the target directory
        if [ -f "$image_target" ]; then
            echo "# Exists in target: \"$image\"" >> $NOT_MOVE
        else
            # Adds a command to move the file to the move script
            echo "mv \"$image\" \"$image_target\"" >> $MOVEFILE
        fi
    else
        # Logs the file that cannot be processed by exiftool
        echo "# Not an image: \"$image\"" >> "$NOT_MOVE"
        echo "The file $image could not be processed"
    fi
}

# Initializes or clears files for logging actions
MOVEFILE=move.sh
NOT_MOVE=cannot_move.txt
echo -n "" > "$MOVEFILE"
chmod +x "$MOVEFILE"
echo -n "" > "$NOT_MOVE"

# Exports variables and functions for use in subshells
export -f process_file
export TARGET_DIR
export SOURCE_DIR
export MOVEFILE
export NOT_MOVE
export PATTERN

# Checks if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: The directory \"$SOURCE_DIR\" does not exist."
    exit 1
fi

# Checks and creates the target directory if it does not exist
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
    if [ $? -eq 0 ]; then
        echo "The directory \"$TARGET_DIR\" has been created."
    else
        echo "Error: The directory \"$TARGET_DIR\" could not be created."
    fi
fi

# Determines the number of CPU cores to optimize parallel processing
N_CORES=$(nproc)

# Uses find and xargs to process files in parallel based on the number of CPU cores
find "$SOURCE_DIR" -type f -print0 | xargs -0 -P "$N_CORES" -I {} bash -c 'process_file "$@"' _ {}

# Summarizes the results of the file processing
COUNT_FOUND=$(wc -l < "$MOVEFILE")
COUNT_NOT_FOUND=$(wc -l < "$NOT_MOVE")
echo "$COUNT_FOUND files found that can be moved."
echo "$COUNT_NOT_FOUND files found that cannot be moved."
