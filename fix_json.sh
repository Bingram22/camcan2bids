#!/bin/bash
module load jq/1.5-GCCcore-10.3.0
bids_dir="camcan_bids"

for i in ${bids_dir}/sub*/ses-stage2/fmap/*phasediff.json; do
    echo "Processing ${i}..."

    # Use jq to delete the EchoTime and EchoNumber fields and add EchoTime1 and EchoTime2
    jq '
        del(.EchoTime, .EchoNumber) |
        .EchoTime1 = 0.00519 |
        .EchoTime2 = 0.00765
    ' "${i}" > temp.json

    # Replace the original file with the modified one
    mv temp.json "${i}"
    echo "${i} updated."
done



# Mapping of runs to tasks
declare -A run_task_mapping
run_task_mapping=( ["run-01"]="task-rest" ["run-02"]="task-movie" ["run-03"]="task-smt" )

# Loop through each subject folder
for subj_dir in "$bids_dir"/sub-*; do
    # Ensure we're working with a directory
    if [[ -d "$subj_dir" ]]; then
        # Find all the fmap JSON files
        for fmap_json in "$subj_dir"/ses-stage2/fmap/*.json; do
            # Check if the JSON file exists
            if [[ -f "$fmap_json" ]]; then
		echo ${fmap_json}
                # Get the run number and magnitude from the JSON filename
                run_number=$(basename "$fmap_json" | grep -oP '(?<=run-)\d{2}')
                magnitude=$(basename "$fmap_json" | grep -oP '(?<=magnitude)\d')

                # Initialize an array to hold intended files
                intended_for=()

                # Find corresponding functional files for the current subject
                for func_file in "$subj_dir"/ses-stage2/func/*_bold.nii.gz; do
                    # Check if the functional file matches the intended conditions
                    if [[ -f "$func_file" ]]; then
                        # Extract the task from the functional filename
                        task=$(basename "$func_file" | grep -oP 'task-\w+')
			echo ${task}
                        # Match based on the run number and task
                        if [[ "$run_number" == "01" && "$task" == "task-rest_bold" ]]; then
                            intended_for+=("ses-stage2/func/$(basename "$func_file")")
			    echo ${intended_for}
                        elif [[ "$run_number" == "02" && "$task" == "task-movie_echo" ]]; then
                            intended_for+=("ses-stage2/func/$(basename "$func_file")")
                        elif [[ "$run_number" == "03" && "$task" == "task-smt_bold" ]]; then
                            intended_for+=("ses-stage2/func/$(basename "$func_file")")
                        fi
                    fi
                done

                # If there are intended files, update the JSON
                if [[ ${#intended_for[@]} -gt 0 ]]; then
                    # Convert array to JSON format
                    intended_for_json=$(printf '%s\n' "${intended_for[@]}" | jq -R . | jq -s .)
		    echo ${intended_for_json}
                    # Update the IntendedFor field in the JSON file
                    jq --argjson intended_for "$intended_for_json" '.IntendedFor = $intended_for' "$fmap_json" > tmp.json && mv tmp.json "$fmap_json"
                fi
            fi
        done
    fi
done

for i in ${bids_dir}/sub*/ses-stage2/func/*events*; do
    sed -i 's/,/\t/g' ${i}
done

# Delete MTI
rm -r camcan_bids/sub-*/ses-stage2/mti/

# Delete Empty Folders
find ${bids_dir} -type d -empty -delete
