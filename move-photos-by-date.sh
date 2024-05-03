#!/bin/bash

# This script organizes images into directories based on their EXIF creation date.
# See README.md.

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

# Define a function to process a single image file
process_file() {
    # Ensure a file path is provided
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

    local image_source=$1
    local year month day

    # Extract EXIF creation date and organize based on the pattern
    if exiftool "$image_source" &> /dev/null; then

        # Try to extract the original date the photo was taken from its metadata (year, month, day) using DateTimeOriginal
        read year month day <<< $(exiftool -d "%Y %m %d" -m -DateTimeOriginal "$image_source" | awk '/Date\/Time Original/ {print $4, $5, $6}')
        
        # Check if the year variable has a value
        if [ -z "$year" ]; then
            # If year is empty, try CreationDate tag
            read year month day <<< $(exiftool -d "%Y %m %d" -m -CreationDate "$image_source" | awk '/Creation Date/ {print $4, $5, $6}')
            
            # Check again if the year variable has a value
            if [ -z "$year" ]; then
                # If still no year, log the error with the image filename to a file
                echo -e "# No creation date found:\n\"$image_source\\n" >> $NOT_MOVE
                return
            fi
        fi

        # Create target directory based on the pattern
        if [ "$PATTERN" = "y-m-d" ]; then
            local target_dir="$TARGET_BASE_DIR/$year/$month/$day"
        elif [ "$PATTERN" = "y-m" ]; then
            local target_dir="$TARGET_BASE_DIR/$year/$month"
        fi

        # Create directory
        # mkdir -p "$target_dir"
        
        local image_base=$(basename "$image_source")
        local image_target="$target_dir/$image_base"

        # Attempt to move the image file
        move_target "$image_source" "$image_target"

        # Handle associated XMP file if exists
        local image_source_xmp="${image_source%.*}.xmp"
        local image_target_xmp="$target_dir/${image_base%.*}.xmp"
        if [ -f "$image_source_xmp" ]; then
            move_target "$image_source_xmp" "$image_target_xmp"
        fi

        # Handle associated DOP file if exists
        local image_source_dop="$image_source.dop"
        local image_target_dop="$target_dir/$image_base.dop"
        if [ -f "$image_source_dop" ]; then
            move_target "$image_source_dop" "$image_target_dop"
        fi

    else
        # Log unprocessable files
        echo -e "# File is not an image:\n\"$image_source\"\n" >> "$NOT_MOVE"
    fi
}

# Export function for subprocesses
export -f process_file

# Initialize log files for actions
export MOVEFILE=move.sh
export NOT_MOVE=cannot_move.txt
FILES_LIST=files.txt
echo -n "" > "$MOVEFILE"
chmod +x "$MOVEFILE"
echo -n "" > "$NOT_MOVE"
echo -n "" > "$FILES_LIST"

# Construct find command's string to exclude directories from the search
EXCLUDE_DIR=""
if [ ! -z "$EXCLUDE_DIRS" ]; then
    IFS=',' read -ra ADDR <<< "$EXCLUDE_DIRS" # Splits the EXCLUDE_DIRS variable into an array
    if [ ${#ADDR[@]} -gt 0 ]; then
        # Constructs the exclusion string for find, starting with the first directory
        EXCLUDE_DIR="-not -path \"*/${ADDR[0]}/*\""
        for i in "${ADDR[@]:1}"; do
            # Adds additional directories to the exclusion
            EXCLUDE_DIR="$EXCLUDE_DIR -not -path \"*/$i/*\""
        done
    fi
fi

# Construct find command's include string for file extensions
FILE_TYPES=""
if [ ! -z "$FILE_EXTENSIONS" ]; then
    IFS=',' read -ra ADDR <<< "$FILE_EXTENSIONS" # Splits the FILE_EXTENSIONS variable into an array
    if [ ${#ADDR[@]} -gt 0 ]; then
        # Constructs the inclusion string for find, starting with the first directory
        FILE_TYPES="-iname \"*.${ADDR[0]}\""
        for i in "${ADDR[@]:1}"; do
            # Adds additional directories to the inclusion
            FILE_TYPES="$FILE_TYPES -o -iname \"*.$i\""
        done
        # Encloses the inclusion string in parentheses and appends it for the find command
        FILE_TYPES="\( $FILE_TYPES \)"
    fi
else
    FILE_TYPES=" -not \( -iname \"*.xmp\" -o -iname \"*.dop\" \)"
fi

# Validate source directory existence
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: The directory \"$SOURCE_DIR\" does not exist."
    exit 1
fi

# Optimize processing using available CPU cores
N_CORES=$(nproc)

# Inform user
echo "Analyzing source directory \"$SOURCE_DIR\"..."
TOTAL_FILES=$(find $SOURCE_DIR -type f | wc -l)

# Display number of total files in folder
echo "$TOTAL_FILES total files"

# Initialize the array for the files
FILES_FILTERED=()
while IFS= read -r line; do
    FILES_FILTERED+=("$line")
done < <(eval "find $SOURCE_DIR -type f $FILE_TYPES $EXCLUDE_DIR")
unset IFS

# Initialize an array for the sorted files
FILES_FILTERED_SORTED=() 
while IFS= read -r line; do
    FILES_FILTERED_SORTED+=("$line")
done < <(printf "%s\n" "${FILES_FILTERED[@]}" | sort)
unset IFS
unset FILES_FILTERED
COUNT_FILTERED_FILES=${#FILES_FILTERED_SORTED[@]}

# Create an array with basenames
SORTED_FILES_WITH_BASENAMES=()
for fullpath in "${FILES_FILTERED_SORTED[@]}"; do
    # Extract the filename without path
    filename="${fullpath##*/}"  # Removes everything up to the last '/'
    # Add the filename and the full path to the array
    SORTED_FILES_WITH_BASENAMES+=("$filename"$'\t'"$fullpath")
done
unset FILES_FILTERED_SORTED

# Analyze the temporary file for duplicates
awk -F'\t' '{
    count[$1]++;
    line[$1] = line[$1] "\"" $2 "\"\n";  # Add quotes around each line
} END {
    for (name in count) {
        if (count[name] > 1) {
            print "# Duplicates:" > "'"$NOT_MOVE"'";
            print line[name] > "'"$NOT_MOVE"'";  # Output with quotes around each line
        } else {
            sub(/\n$/, "", line[name]);  # Remove the last newline
            print line[name] > "'"$FILES_LIST"'";
        }
    }
}' < <(printf "%s\n" "${SORTED_FILES_WITH_BASENAMES[@]}")
unset SORTED_FILES_WITH_BASENAMES

# Count number of duplicate and unique files
COUNT_DUPLICATE_FILES=$(grep -c '^"' $NOT_MOVE)
COUNT_UNIQUE_FILES=$(grep -c '^"' $FILES_LIST)

# Use find and xargs to process files in parallel, considering file extensions and exclusions
echo "Analyzing the candidates..."
cat "$FILES_LIST" | xargs -P "$N_CORES" -I {} bash -c 'process_file "$@"' _ {}

# Summarize and report the outcome
echo "Summary for source files ($SOURCE_DIR):"
printf "%8s total files\n" "$TOTAL_FILES"
printf "%8s filtered files\n" "$COUNT_FILTERED_FILES"
printf "%8s duplicate files\n" "$COUNT_DUPLICATE_FILES"
printf "%8s unique files\n" "$COUNT_UNIQUE_FILES"

COUNT_NOT_AN_IMAGE=$(grep -c 'File is not an image' $NOT_MOVE) 
printf "%8s files are not an image (see cannot_move.txt)\n" "$COUNT_NOT_AN_IMAGE"

COUNT_NO_CREATION_DATE=$(grep -c 'No creation date' $NOT_MOVE)
printf "%8s files have no creation date (see cannot_move.txt)\n" "$COUNT_NO_CREATION_DATE"

echo -e "\nResults from comparison with target directory ($TARGET_BASE_DIR):"
COUNT_FOUND=$(wc -l < "$MOVEFILE")
printf "%8s files found that can be moved (see move.sh)\n" "$COUNT_FOUND"

COUNT_EXISTS_IN_TARGET=$(grep -c 'File already exists at target' $NOT_MOVE) 
printf "%8s files exist in target moved (see cannot_move.txt)\n" "$COUNT_EXISTS_IN_TARGET"