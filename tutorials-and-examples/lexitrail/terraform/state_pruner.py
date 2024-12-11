import json

# List of resource types to delete
resource_types_to_delete = ["kubectl_manifest", "helm_release"]

# Set dry_run mode
dry_run = False  # Set to False to actually delete resources

def delete_specified_types_from_state(file_path):
    # Load the Terraform state
    with open(file_path, 'r') as file:
        state = json.load(file)

    # Track resources to delete
    resources_to_delete = set()

    # Initial scan: Mark resources of specified types for deletion
    for index, resource in enumerate(state.get("resources", [])):
        if resource["type"] in resource_types_to_delete:
            resources_to_delete.add(index)
            print(f"{'Dry Run: ' if dry_run else ''}Marking resource '{resource['name']}' (type: {resource['type']}) for deletion.")

    # Recursive dependency check
    for _ in range(len(state["resources"])):
        new_deletions = set()
        for index, resource in enumerate(state["resources"]):
            if index in resources_to_delete:
                continue
            # Check if this resource has dependencies on resources marked for deletion
            for dep_index in resources_to_delete:
                dep_resource = state["resources"][dep_index]
                # If the current resource depends on any marked-for-deletion resource
                if "depends_on" in resource and dep_resource["name"] in resource["depends_on"]:
                    new_deletions.add(index)
                    print(f"{'Dry Run: ' if dry_run else ''}Marking dependent resource '{resource['name']}' (type: {resource['type']}) for deletion due to dependency.")
                    break
        if not new_deletions:
            break  # No new dependencies, end recursion
        resources_to_delete.update(new_deletions)

    # Filter resources and update state file if not in dry run mode
    if not dry_run:
        state["resources"] = [resource for index, resource in enumerate(state["resources"]) if index not in resources_to_delete]
        with open(file_path, 'w') as file:
            json.dump(state, file, indent=2)
        print("Resources deleted and state file updated.")
    else:
        print("Dry Run Complete: No resources were actually deleted.")

# Specify the path to the state file
state_file_path = "terraform.tfstate"
delete_specified_types_from_state(state_file_path)
