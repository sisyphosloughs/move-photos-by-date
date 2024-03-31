#!/bin/bash

# This script organizes images into directories based on their EXIF creation date.

# Checks if the correct number of arguments is passed to the script
if [ $# -lt 3 ]; then
    echo "Usage: $0 <Pattern: y-m-d/y-m> <SourceDirectoryPath> <TargetDirectoryPath>"
    echo "Example: $0 y-m-d /path/to/folder/Source /path/to/folder/Target"
    exit 1
fi

# Validates the date pattern argument to ensure it's either 'y-m-d' or 'y-m'
if [[ $1 != "y-m-d" && $1 != "y-m" ]]; then
    echo "Error: The first parameter must be either 'y-m-d' or 'y-m'."
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

# Initializes variables with the script's arguments
PATTERN=$1
SOURCE_DIR=$2
TARGET_DIR=$3

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
