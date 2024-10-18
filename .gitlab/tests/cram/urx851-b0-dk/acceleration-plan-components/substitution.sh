#!/bin/bash


# Function: substitute_variables
# Purpose: Automatically expand all predefined variables from the variable files 
#          in the template file to generate a final file.
# Parameters:
#   varfile: The variable file location.
#   templatefile: The input template file location including variables to substitute.
#   outfilepath: The output file with all predefined variables substituted.
substitute_variables() {

    # Handle vars
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --varfile) varfile="$2"; shift 2;;
            --templatefile) templatefile="$2"; shift 2;;
            --outfilepath) outfilepath="$2"; shift 2;;          
            *) echo "Unknown option: $1"; return 1;;
        esac
    done

    if [ -z "$varfile" ] || [ -z "$templatefile" ] || [ -z "$outfilepath" ]; then
        echo "Missing mandatory variable(s)"; return 1
    fi

    while IFS= read -r line; do
        # Escape empty lines and comment lines (using a non 'bash' specific syntax)
        first_char=$(echo "$line" | sed 's/^[[:space:]]*//; s/^\(.\).*/\1/')
        if [ "$first_char" == "#" ] || [ -z "$line" ]; then
            continue
        fi

        ## Extract the variable name and add it to a list of all variables
        var_name=$(echo "$line" | awk -F'=' '{print $1}')
        var_value=$(echo "$line" | awk '{print substr($0, index($0, "=") + 1)}')
        var_names+=("$var_name")

        ## Export the variable (after adding necessairy escape character)
        formatted_line=$(eval echo "$var_value" | sed -e 's/"/\\"/g' -e 's/\\/\\\\\\/g')
        eval export "$var_name"='${formatted_line}'

    done < "${varfile}"

    # Create the list of all variable to be replaced
    var_to_replace=$(printf ' $%s' "${var_names[@]}")

    ## Proceed with substituting all variables that were requested
    envsubst "$var_to_replace" < "$templatefile" > "$outfilepath"
}


# Function: expand_all_files
# Purpose: Loop over all existing files and make substitute the env variables 
#          in the files with suffix "-template.t"
# Parameters:
#   directory: The location of the template files and the env variable file.
#   output_directory: The location of the output files.
#
# Return Value:
#   The function print the name of all generated files.
expand_all_files() {
    # Loop through the arguments
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --directory) directory="$2"; shift 2;;  
            --out_directory) out_directory="$2"; shift 2;;
            --variables) variables="$2"; shift 2;;
            *) echo "Unknown option: $1"; return 1;;
        esac
    done

    if [ -z "$directory" ] || [ -z "$out_directory" ] || [ -z "$variables" ]; then
        echo "Missing mandatory variable(s)"; return 1
    fi

    cd "$directory" || return 1
    ## Iterate over all files with "-tempate.t" suffix and proceed
    ## with substituting the env variables.
    for filename in *-template.t; do
            outfilename=${filename/"-template"/}
            outfilelocation=${out_directory}/${outfilename}

            substitute_variables    --varfile "$variables" --templatefile "$filename" \
                                    --outfilepath "$outfilelocation" && \
                                    echo "Generated test file located in: ${outfilelocation}" || \
                                    echo "Failed to substite variables for file ${outfilelocation}"
    done
}

# Function to display help
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Substitutes the values of environment variables defined in a file and used"
    echo "in cram script files named xxx-template.t"
    echo ""
    echo "Optional parameters:"
    echo "  --variables <variable_file_path>   path to the file containing variable definitions (optional)"
    echo "                                     when not provided, the file \"variables.env\" will be used"
    echo "  --outdir <output_dir_path>         directory where the output files will be stored (optional)"
    echo "                                     When not provided, a random temporary directory will be generated and used"
    echo "  -h, --help                         display this help and exit"
    echo ""
    exit 0
}

# Loop through the arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --variables) variables="$2"; shift 2;;  
        --outdir) out_directory="$2"; shift 2;;  
        -h|--help) usage;;
        *) echo "Unknown option: $1"; exit 1;;
    esac
done


workdir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

if [ -z "$workdir" ]; then
    echo "Could not extract the scripts' directory"
    exit 1
fi

## If no output directory defined, a generated temp 
## directory will be used.
if [ -z "$out_directory" ]; then
    out_directory=$(mktemp -d)
fi

# If no variables files location is provided, the 
# file name and location are expected to be the 
# default ones: same directoy as the script and the file 
# name is "variables.env"
if [ -z "$variables" ]; then
    variables=$workdir/variables.env
fi

# Check the existance of the variable file
if [ ! -f "$variables" ]; then
    echo "${variables} file not found. No variable expansion to be done"
    exit 1
fi

expand_all_files --directory "$workdir" --out_directory "$out_directory" --variables "$variables"
echo "Output files location is: \"${out_directory}\""
