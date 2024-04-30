#!/bin/bash

# This script organizes images into directories based on their EXIF creation date.

# Initialize variables
TARGET_BASE_DIR=""
SOURCE_DIR=""
PATTERN=""
EXCLUDE_DIRS=""
FILE_EXTENSIONS=""

# Define option string for getopts
OPTSTRING=":t:s:p:e:f:"

# Process input options
while getopts ${OPTSTRING} opt; do
  case ${opt} in
    t) # Target directory
      export TARGET_BASE_DIR="${OPTARG}"
      ;;
    s) # Source directory
      export SOURCE_DIR="${OPTARG}"
      ;;
    p) # Date pattern for organizing
      export PATTERN="${OPTARG}"
      ;;
    e) # Directories to exclude from the search
      EXCLUDE_DIRS="${OPTARG}"
      ;;
    f) # File extensions to include
      FILE_EXTENSIONS="${OPTARG}"
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
if [ -z "${TARGET_BASE_DIR}" ] || [ -z "${SOURCE_DIR}" ] || [ -z "${PATTERN}" ] || [ $# -eq 0 ]; then
    echo "Usage: $0 -p <Pattern: y-m-d/y-m> -s <SourceDirectoryPath> -t <TargetDirectoryPath> [-e <ExcludeDirectories>] [-f <FileExtensions>]"
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

    # Function to decide whether to move a file or log it as existing/not movable
    move_target(){
        local source_file_path="$1"         # Full path of the source file
        local target_file_path="$2"         # Full path of the target file
        local filename=$(basename "$2")     # Remove the path from $2 and only keep the filename

        if [ -f "$target_file_path" ]; then
            # Check if the file exists at the target
            echo "# File already exists at target:" >> "$NOT_MOVE"
            echo "\"$source_file_path\" # source" >> "$NOT_MOVE"
            echo "\"$target_file_path\" # target" >> "$NOT_MOVE"
            echo "" >> "$NOT_MOVE"
        else
            # If neither condition is met, write the move command to $MOVEFILE
            echo "mv \"$source_file_path\" \"$target_file_path\"" >> "$MOVEFILE"
        fi
    }

    local image=$1
    local year month day

    # Extract EXIF creation date and organize based on the pattern
    if exiftool "$image" &> /dev/null; then

        # Extract the original date the photo was taken from its metadata (year, month, day) and store these values in variables.
        read year month day <<< $(exiftool -d "%Y %m %d" -DateTimeOriginal "$image" | awk '/Date\/Time Original/ {print $4, $5, $6}')   
        
        # Check if the year variable has a value
        if [ -z "$year" ]; then
            # If year is empty, log the error with the image filename to a file and exit the function
            echo "# No creation date found:" >> $NOT_MOVE
            echo "\"$image\"" >> $NOT_MOVE
            echo "" >> $NOT_MOVE
            return
        fi

        # Create target directory based on the pattern
        if [ "$PATTERN" = "y-m-d" ]; then
            local target_dir="$TARGET_BASE_DIR/$year/$month/$day"
        elif [ "$PATTERN" = "y-m" ]; then
            local target_dir="$TARGET_BASE_DIR/$year/$month"
        fi

        # Create directory
        mkdir -p "$target_dir"
        
        local image_base=$(basename "$image")
        local image_target="$target_dir/$image_base"

        # Attempt to move the image file
        move_target "$image" "$image_target"

        # Handle associated XMP file if exists
        local image_source_xmp="${image%.*}.xmp"
        local image_target_xmp="$target_dir/${image_base%.*}.xmp"
        if [ -f "$image_source_xmp" ]; then
            move_target "$image_source_xmp" "$image_target_xmp"
        fi

        # Handle associated DOP file if exists
        local image_source_dop="$image.dop"
        local image_target_dop="$target_dir/$image_base.dop"
        if [ -f "$image_source_dop" ]; then
            move_target "$image_source_dop" "$image_target_dop"
        fi

    else
        # Log unprocessable files
        echo "# File is not an image:" >> "$NOT_MOVE"
        echo "\"$image\"" >> "$NOT_MOVE"
        echo "" >> "$NOT_MOVE"
    fi
}

# Export function for subprocesses
export -f process_file

# Initialize log files for actions
export MOVEFILE=move.sh
export NOT_MOVE=cannot_move.txt
FILES_LIST=files.txt
TEMP_SORT=tmp_sort.txt
echo -n "" > "$MOVEFILE"
chmod +x "$MOVEFILE"
echo -n "" > "$NOT_MOVE"
echo -n "" > "$FILES_LIST"
echo -n "" > "$TEMP_SORT"

# Construct find command's string to exclude directories from the search
EXCLUDE_STRING=""
if [ ! -z "$EXCLUDE_DIRS" ]; then
    IFS=',' read -ra ADDR <<< "$EXCLUDE_DIRS" # Splits the EXCLUDE_DIRS variable into an array
    if [ ${#ADDR[@]} -gt 0 ]; then
        # Constructs the exclusion string for find, starting with the first directory
        EXCLUDE_STRING="-name '${ADDR[0]}'"
        for i in "${ADDR[@]:1}"; do
            # Adds additional directories to the exclusion
            EXCLUDE_STRING="$EXCLUDE_STRING -o -name '$i'"
        done
        # Encloses the exclusion string in parentheses and appends it for the find command
        EXCLUDE_STRING="-type d \( $EXCLUDE_STRING \) -prune -o"
    fi
fi

# Construct find command's include string for file extensions
INCLUDE_STRING=""
if [ ! -z "$FILE_EXTENSIONS" ]; then
    IFS=',' read -ra ADDR <<< "$FILE_EXTENSIONS" # Splits the FILE_EXTENSIONS variable into an array
    if [ ${#ADDR[@]} -gt 0 ]; then
        # Constructs the exclusion string for find, starting with the first directory
        INCLUDE_STRING="-iname '*.${ADDR[0]}'"
        for i in "${ADDR[@]:1}"; do
            # Adds additional directories to the exclusion
            INCLUDE_STRING="$INCLUDE_STRING -o -iname '*.$i'"
        done
        # Encloses the exclusion string in parentheses and appends it for the find command
        INCLUDE_STRING="\( $INCLUDE_STRING \)"
    fi
fi

# Validate source directory existence
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: The directory \"$SOURCE_DIR\" does not exist."
    exit 1
fi

# Optimize processing using available CPU cores
N_CORES=$(nproc)

# Create a temporary file with filenames with and without path
echo "List files and search for duplicates..."
find "$SOURCE_DIR" -type f -not \( -iname "*.xmp" -o -iname "*.dop" \) -print0 | xargs -0 -n 100 -P "$N_CORES" sh -c 'for filepath; do printf "%s\t\"%s\"\n" "$(basename "$filepath")" "$filepath"; done' sh | sort > "$TEMP_SORT"

# Analyze the temporary file for duplicates
awk -F'\t' '{
    count[$1]++;
    line[$1] = line[$1] $2 "\n";
} END {
    for (name in count) {
        if (count[name] > 1) {
            print "# Duplicates: " > "'"$NOT_MOVE"'";
            print line[name] > "'"$NOT_MOVE"'";
        } else {
            sub(/\n$/, "", line[name]);  # Remove the last newline
            print line[name] > "'"$FILES_LIST"'";
        }
    }
}' "$TEMP_SORT"

# Use find and xargs to process files in parallel, considering file extensions and exclusions
echo "Analyze the candidates..."
cat "$FILES_LIST" | xargs -P "$N_CORES" -I {} bash -c 'process_file "$@"' _ {}

# Summarize and report the outcome
COUNT_FOUND=$(wc -l < "$MOVEFILE")
COUNT_NOT_MOVED=$(wc -l < "$NOT_MOVE") # Todo
echo "$COUNT_FOUND files found that can be moved (see move.sh)."
echo "$COUNT_NOT_MOVED files found that cannot be moved (see cannot_move.txt)."

# Cleanup
rm "$TEMP_SORT"
rm "$FILES_LIST"