#!/bin/bash

yum install -y jq

set -eu

aws cloudformation describe-stacks --stack-name "MythicalMysfitsCoreStack" | jq -r '[.Stacks[0].Outputs[] | {key: .OutputKey, value: .OutputValue}] | from_entries' > cfn-output.json

# declare an associative array, the -A defines the array of this type
declare -A cfnOutputs

# The output of jq is separated by '|' so that we have a valid delimiter
# to read our keys and values. The read command processes one line at a 
# time and puts the values in the variables 'key' and 'value'
while IFS='|' read -r key value; do
    # Strip out the text until the last occurrence of '/' 
    strippedKey="${key##*/}"
    # Putting the key/value pair in the array
    cfnOutputs["$strippedKey"]="$value"
done< <(jq -r 'keys[] as $k | "\($k)|\(.[$k])"' cfn-output.json)

# Print the array using the '-p' or do one by one
#declare -p cfnOutputs

sed -i -e 's/REPLACE_ME_CODEBUILD_ROLE_ARN/'"${cfnOutputs[CodeBuildRole]}"'/' \
       -e 's/REPLACE_ME_CODEPIPELINE_ROLE_ARN/'"${cfnOutputs[CodePipelineRole]}"'/' \
       -e 's/REPLACE_ME_ARTIFACTS_BUCKET_NAME/'"${cfnOutputs[MythicalArtifactBucket]}"'/' aws-cli/artifacts-bucket-policy.json

sed -i -e 's/AWS_ACCOUNT_ID/'"${cfnOutputs[CurrentAccount]}"'/' \
       -e 's/REPLACE_ME_REGION/'"${cfnOutputs[CurrentRegion]}"'/' \
       -e 's/REPLACE_ME_CODEBUILD_ROLE_ARN/'"${cfnOutputs[CodeBuildRole]}"'/' aws-cli/code-build-project.json
       
sed -i -e 's/REPLACE_ME_CODEBUILD_ROLE_ARN/'"${cfnOutputs[CodeBuildRole]}"'/' aws-cli/ecr-policy.json

aws s3api put-bucket-policy --bucket ${cfnOutputs[MythicalArtifactBucket]} --policy file://~/environment/aws-modern-application-workshop/module-2/aws-cli/artifacts-bucket-policy.json

aws codecommit create-repository --repository-name MythicalMysfitsService-Repository

aws codepipeline create-pipeline --cli-input-json file://~/environment/aws-modern-application-workshop/module-2/aws-cli/code-pipeline.json

aws ecr set-repository-policy --repository-name mythicalmysfits/service --policy-text file://~/environment/aws-modern-application-workshop/module-2/aws-cli/ecr-policy.json
