from google.api_core import exceptions as core_exceptions  # Import core exceptions
from google.auth import exceptions as auth_exceptions
from google.cloud import compute_v1


def list_regions_with_zones(project_id):
  """Lists all regions and their zones within a GCP project."""
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
    return {}
  except Exception as e:
    print(f"An error occurred: {e}")
    return {}


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
  except core_exceptions.NotFound as e:  # Use google.api_core.exceptions
    # Machine type not found is a 404, so we catch it specifically.
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


from google.cloud import compute_v1
from google.auth import exceptions as auth_exceptions
from google.api_core import exceptions as core_exceptions
import json


def list_regions_with_zones(project_id):
  """Lists all regions and their zones within a GCP project."""
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
    return {}
  except Exception as e:
    print(f"An error occurred: {e}")
    return {}


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


if __name__ == "__main__":
  project_id = "supercomputer-testing"  # Replace with your project ID
  machine_type_to_check = "a3-megagpu-8g"

  write_zone_to_region_map_to_json(project_id)

  # # Example 1: Check availability in a single zone
  # zone_to_check = "us-east1-b"
  # if is_machine_type_available(project_id, zone_to_check, machine_type_to_check):
  #     print(f"Machine type '{machine_type_to_check}' is available in '{zone_to_check}'.")
  # else:
  #     print(f"Machine type '{machine_type_to_check}' is NOT available in '{zone_to_check}'.")

  # # Example 2: Check in multiple zones
  # regions_and_zones = list_regions_with_zones(project_id)
  # all_zones = []
  # for zones in regions_and_zones.values():
  #     all_zones.extend(zones)

  # availability_results = check_machine_type_in_zones(
  #     project_id, all_zones, machine_type_to_check
  # )

  # print(f"\nAvailability of '{machine_type_to_check}':")
  # for zone, available in availability_results.items():
  #     status = "Available" if available else "Not Available"
  #     print(f"- {zone}: {status}")

  # # Example 3: Check in specific zones
  # specific_zones_to_check = ["us-central1-a", "us-east1-b", "europe-west1-b"]
  # availability = check_machine_type_in_zones(project_id, specific_zones_to_check, machine_type_to_check)
  # print(f"\nAvailability of '{machine_type_to_check}' in specific zones:")
  # for zone, is_available in availability.items():
  #     print(f"  - {zone}: {'Available' if is_available else 'Not Available'}")
