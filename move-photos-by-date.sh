#!/bin/bash

# This script organizes images into directories based on their EXIF creation date.

# Initialize variables
TARGET_DIR=""
SOURCE_DIR=""
PATTERN=""
EXCLUDE_DIRS=""

OPTSTRING=":t:s:p:e:"

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
    e)
      EXCLUDE_DIRS="${OPTARG}"
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
if [ -z "${TARGET_DIR}" ] || [ -z "${SOURCE_DIR}" ] || [ -z "${PATTERN}" ] || [ $# -eq 0 ]; then
    echo "Usage: $0 -p <Pattern: y-m-d/y-m> -s <SourceDirectoryPath> -t <TargetDirectoryPath> [-e <ExcludeDirectories>]"
    echo "Example: $0 -p y-m-d -s /path/to/source -t /path/to/target -e @eaDir,tmp"
    echo "Note: The parameter -e <ExcludeDirectories> is optional."
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

# Constructs a string to exclude directories from the search
EXCLUDE_STRING=""
if [ ! -z "$EXCLUDE_DIRS" ]; then
    IFS=',' read -ra ADDR <<< "$EXCLUDE_DIRS" # Splits the EXCLUDE_DIRS variable into an array
    if [ ${#ADDR[@]} -gt 0 ]; then
        # Constructs the exclusion string for find, starting with the first directory
        EXCLUDE_STRING="-name ${ADDR[0]}"
        for i in "${ADDR[@]:1}"; do
            # Adds additional directories to the exclusion
            EXCLUDE_STRING="$EXCLUDE_STRING -o -name $i"
        done
        # Encloses the exclusion string in parentheses and appends it for the find command
        EXCLUDE_STRING="( $EXCLUDE_STRING ) -prune -o"
    fi
fi

# Checks if the source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: The directory \"$SOURCE_DIR\" does not exist."
    exit 1
fi

# Determines the number of CPU cores to optimize parallel processing
N_CORES=$(nproc)

# Uses find and xargs to process files in parallel based on the number of CPU cores

find "$SOURCE_DIR" $EXCLUDE_STRING  -type f -print0 | xargs -0 -P "$N_CORES" -I {} bash -c 'process_file "$@"' _ {}
#find "$SOURCE_DIR" -type f -print0 | xargs -0 -P "$N_CORES" -I {} bash -c 'process_file "$@"' _ {}


# Summarizes the results of the file processing
COUNT_FOUND=$(wc -l < "$MOVEFILE")
COUNT_NOT_FOUND=$(wc -l < "$NOT_MOVE")
echo "$COUNT_FOUND files found that can be moved."
echo "$COUNT_NOT_FOUND files found that cannot be moved."
