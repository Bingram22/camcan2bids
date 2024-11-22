#!/bin/bash

#SBATCH --account bagshaap-eeg-fmri-hmm
#SBATCH --qos bbdefault
#SBATCH --time 120
#SBATCH --nodes 1  # ensure the job runs on a single node
#SBATCH --ntasks 10  # this will give you circa 40G RAM and will ensure faster conversion to the .sif format
#SBATCH --constraint icelake

# Base directories
base_dir="/rds/projects/q/quinna-camcan-mri/data_repo/cc700/mri/pipeline/release004"
bids_dir="${base_dir}/camcan_bids"

# Ensure the BIDS directory exists
mkdir -p "$bids_dir"

# Create Dataset Description
cat <<EOL > ${bids_dir}/dataset_description.json
{
  "Acknowledgements": "TODO: whom you want to acknowledge",
  "Authors": [
    "TODO:",
    "First1 Last1",
    "First2 Last2",
    "..."
  ],
  "BIDSVersion": "1.4.1",
  "DatasetDOI": "TODO: eventually a DOI for the dataset",
  "Funding": [
    "TODO",
    "GRANT #1",
    "GRANT #2"
  ],
  "HowToAcknowledge": "TODO: describe how to acknowledge -- either cite a corresponding paper, or just in acknowledgement section",
  "License": "TODO: choose a license, e.g. PDDL (http://opendatacommons.org/licenses/pddl/)",
  "Name": "TODO: name of the dataset",
  "ReferencesAndLinks": [
    "TODO",
    "List of papers or websites"
  ]
}
EOL

# Create task json files

# movie
cat <<EOL > ${bids_dir}/task-movie_bold.json
{
    "RepetitionTime": 2.470,
    "TaskName": "Movie watching (rest)"
}
EOL

# smt
cat <<EOL > ${bids_dir}/task-smt_bold.json
{
    "RepetitionTime": 1.970,
    "TaskName": "Sensori-motor task"
}
EOL

# smt
cat <<EOL > ${bids_dir}/task-rest_bold.json
{
    "RepetitionTime": 1.970,
    "TaskName": "Rest"
}
EOL

# create README

cat <<EOL > ${bids_dir}/README
This folder contains the CAMCAN MRI data organised acording to BIDS. To save storage space, nifti files are soft links to the original data.
EOL



# Loop through each subject directory that starts with 'sub-' in the anat directory
for subject in ${base_dir}/BIDS_20190411/anat/sub-*; do
    subject_name=$(basename "$subject")
    echo "Processing subject: $subject_name"

    # Create the subject directory in BIDS if it doesn't exist
    mkdir -p "$bids_dir/$subject_name"

    # Now search for modalities in the entire subject directory, not just anat
    for modality in ${base_dir}/BIDS_20190411/* ; do
        modality_name=$(basename "$modality")

        # Check for modalities starting with 'epi_' or 'fmap_'
        if [[ "$modality_name" == epi_* ]]; then
            target_modality="func"
            task_tag=$(echo "$modality_name" | awk -F'_' '{print $2}')
        elif [[ "$modality_name" == fmap_* ]]; then
            target_modality="fmap"
            task_tag=$(echo "$modality_name" | awk -F'_' '{print $2}')
        else
            target_modality=${modality_name}
        fi

        # Create the func or fmap folder in BIDS
        mkdir -p "$bids_dir/$subject_name/ses-stage2/$target_modality"

for file in ${modality}/${subject_name}/*/*; do
    # Check if the file exists
    if [[ -e "$file" ]]; then
        # Extract the base name (removes the path)
        basename=$(basename "$file")

        # Extract the file extension (everything after the last '.')
        extension="${basename##*.}"

        # Extract the base name without the extension
        base="${basename%.*}"

        # Check if the base name has another extension (for files like .nii.gz)
        if [[ "$base" == *.* ]]; then
            extension="${base##*.}.$extension"
        fi

        # Print the file name and its extension (or perform other actions)
        echo "File: $basename, Extension: $extension"

        if [[ $target_modality == "func" ]]; then
            if [[ $extension == 'tsv' ]]; then
                end_tag='events'
	    else
                end_tag='bold'
	    fi
            if [[ ${task_tag} == 'movie' ]]; then
                echo_number=$(echo "$file" | sed 's/.*_echo\([0-9]\+\)\..*/\1/')
                bids_file_name="${subject_name}_ses-stage2_task-${task_tag}_echo-0${echo_number}_${end_tag}.${extension}"
            else
                bids_file_name="${subject_name}_ses-stage2_task-${task_tag}_${end_tag}.${extension}"
            fi
        elif [[ $target_modality == "fmap" ]]; then

	    if [[ ${task_tag} == "rest" ]]; then
                run_tag="01"
            elif [[ ${task_tag} == "movie" ]];then
                run_tag="02"
            elif [[ ${task_tag} == "smt" ]]; then
                run_tag="03"
	    fi


            if [[ ! "$file" == *"run"* ]]; then
                end_tag="phasediff"
            elif [[ "$file" == *"run-01"* ]]; then
                end_tag="magnitude1"
            elif [[ "$file" == *"run-02"* ]]; then
                end_tag="magnitude2"
            fi
            bids_file_name="${subject_name}_ses-stage2_run-${run_tag}_${end_tag}.${extension}"
        else
	    echo IT DID THE ELSE THING
            # For anat, dwi, mti, or any other modality
	    bids_file_name=$(basename "$file")
	    echo ${bids_file_name}
	    bids_file_name=$(echo "$bids_file_name" | sed "s/${subject_name}_/${subject_name}_ses-stage2_/")
	    echo ${bids_file_name}
        fi

	if [[ ${extension} == 'nii.gz' ]]; then
            # Link the file only if it exists

            cp "$file" "$bids_dir/$subject_name/ses-stage2/$target_modality/${bids_file_name}"
	else
	    cp "${file}" "$bids_dir/$subject_name/ses-stage2/$target_modality/${bids_file_name}"
        fi

    else
        echo "Warning: File does not exist: $file"
    fi
done
done
done

for i in ${bids_dir}/sub*/fmap/*phasediff.json ; do
	echo ${i}
done
