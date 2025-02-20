from google.api_core import exceptions as core_exceptions
from google.auth import exceptions as auth_exceptions
from google.cloud import compute_v1
import yaml
import json
import argparse

def list_regions_with_zones(project_id):
  """Lists all regions and their zones within a GCP project.

  Returns:
      A dictionary where keys are region names and values are lists of zone names in that region.
      Returns an empty dictionary if an error occurs.
  """
  try:
    compute_client = compute_v1.RegionsClient()
    zones_client = compute_v1.ZonesClient()

    request = compute_v1.ListRegionsRequest(project=project_id)
    regions_pager = compute_client.list(request=request)

    region_zones = {}
    for region in regions_pager:
      region_name = region.name
      region_zones[region_name] = []

      zone_request = compute_v1.ListZonesRequest(project=project_id)
      zones_pager = zones_client.list(request=zone_request)

      for zone in zones_pager:
        if region_name in zone.region:
          region_zones[region_name].append(zone.name)

    return region_zones

  except auth_exceptions.DefaultCredentialsError as e:
    print(f"Authentication error: {e}")
    return {} # Return empty dict on authentication error
  except Exception as e:
    print(f"An error occurred: {e}")
    return {} # Return empty dict on general error


def is_machine_type_available(project_id, zone, machine_type):
  """Checks if a specific machine type is available in a given zone."""
  try:
    machine_types_client = compute_v1.MachineTypesClient()

    request = compute_v1.GetMachineTypeRequest(
        project=project_id, zone=zone, machine_type=machine_type
    )
    machine_types_client.get(request=request)
    return True

  except auth_exceptions.DefaultCredentialsError as e:
    print(f"Authentication error: {e}")
    return False
  except core_exceptions.NotFound as e:
    # Machine type not found in zone
    return False
  except Exception as e:
    print(f"An error occurred: {e}")
    return False


def check_machine_type_in_zones(project_id, zones, machine_type):
  """Checks a machine type across multiple zones."""
  availability = {}
  for zone in zones:
    availability[zone] = is_machine_type_available(
        project_id, zone, machine_type
    )
  return availability


def create_zone_to_region_map(project_id):
  """Creates a reverse lookup map from zone to region, leveraging list_regions_with_zones.

  Args:
      project_id: The ID of the Google Cloud project.

  Returns:
      A dictionary where keys are zone names (strings) and values are
      region names (strings). Returns an empty dictionary on error.
  """
  regions_with_zones = list_regions_with_zones(project_id)
  if not regions_with_zones:
    return {}  # Return empty dict if list_regions_with_zones failed

  zone_to_region = {}
  for region, zones in regions_with_zones.items():
    for zone in zones:
      zone_to_region[zone] = region
  return zone_to_region


def write_zone_to_region_map_to_json(
    project_id, filename="zone_to_region.json"
):
  """Creates a zone-to-region map and writes it to a JSON file."""
  zone_to_region = create_zone_to_region_map(project_id)
  if zone_to_region:
    try:
      with open(filename, "w") as f:
        json.dump(zone_to_region, f, indent=4)
      print(f"Successfully wrote zone-to-region map to '{filename}'")
    except Exception as e:
      print(f"Error writing to file: {e}")
  else:
    print("Failed to create zone-to-region map.")

def get_available_zones(project_id, machine_type):
  """Retrieves the list of zones where a given machine type is available."""
  regions_and_zones = list_regions_with_zones(project_id)
  all_zones = []
  for zones in regions_and_zones.values():
      all_zones.extend(zones)

  availability_results = check_machine_type_in_zones(
      project_id, all_zones, machine_type
  )

  available_zones = [
      zone for zone, available in availability_results.items() if available
  ]
  return available_zones

def update_blueprint_metadata(project_id, machine_type, blueprint_file="metadata.display.yaml"):
  """Updates the allowlisted_zones in the blueprint metadata file based on machine type availability."""
  try:
    with open(blueprint_file, 'r') as file:
      blueprint_data = yaml.safe_load(file)

    available_zones = get_available_zones(project_id, machine_type)

    if machine_type == "a3-megagpu-8g":
        blueprint_data['spec']['ui']['input']['variables']['a3_mega_zone']['xGoogleProperty']['gce_zone']['allowlisted_zones'] = available_zones
    elif machine_type == "a3-ultragpu-8g":
        blueprint_data['spec']['ui']['input']['variables']['a3_ultra_zone']['xGoogleProperty']['gce_zone']['allowlisted_zones'] = available_zones
    else:
        print(f"machine type {machine_type} is not supported")
        return

    with open(blueprint_file, 'w') as file:
      yaml.dump(blueprint_data, file, sort_keys=False)

    print(f"Updated {blueprint_file} with available zones for {machine_type}.")

  except FileNotFoundError:
    print(f"Error: {blueprint_file} not found.")
  except Exception as e:
    print(f"An error occurred: {e}")

if __name__ == "__main__":
  parser = argparse.ArgumentParser(description="Update blueprint metadata with available zones and regions for given machine types.")
  parser.add_argument("--project_id", required=True, help="Your Google Cloud project ID.") 
  args = parser.parse_args()
  write_zone_to_region_map_to_json(args.project_id)
  update_blueprint_metadata(args.project_id, "a3-megagpu-8g")
  update_blueprint_metadata(args.project_id, "a3-ultragpu-8g")