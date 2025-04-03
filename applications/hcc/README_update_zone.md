# GCP Zone and Region Availability Updater

This Python script updates zones and regions in a metadata YAML file and a JSON file based on the availability of specific Google Compute Engine (GCE) machine types in a given Google Cloud Project. It provides two main functionalities:

1. **Updating Zones in YAML:** It updates the `allowlisted_zones` field in a YAML file (`metadata.display.yaml`) for specified machine types (e.g., "a3-megagpu-8g", "a3-ultragpu-8g"). 

2. **Generating Zone-to-Region Mapping:** It generates a JSON file (e.g., `zone_to_region.json`) that provides a mapping between zones and their corresponding regions in your GCP project. The main reason why we need `zone_to_region.json` is for region lookup in [region.tf](https://github.com/GoogleCloudPlatform/ai-on-gke/blob/qss-poc/applications/hcc/region.tf#L2).

The script uses the Google Cloud Compute Engine API to retrieve information about regions, zones, and machine type availability. It leverages the `google-cloud-compute` and `PyYAML` libraries for interacting with the API and processing YAML files.

## Prerequisites

* **Python 3.6 or higher**
* **Google Cloud Project:** A project with the necessary APIs enabled (Compute Engine API).
* **Authentication:** Ensure your environment is authenticated to your Google Cloud Project. The easiest way is to use the `gcloud` command-line tool:
   ```bash
   gcloud auth application-default login
   ```
* **Required Python packages:**
  ```Bash
  pip install google-cloud-compute PyYAML
  ```
## Usage
* Run the script with the `--project_id` argument:
  ```Bash
  cd ./applications/hcc/
  python update_zone_region.py --project_id your-project-id
  ```
  Replace `your-project-id` with your actual Google Cloud Project ID.


### Example
To update the `metadata.display.yaml` file with the available zones for the `a3-megagpu-8g` and `a3-ultragpu-8g` machine types in the `your-project-id` project, and generate the `zone_to_region.json` file:
```Bash
cd ./applications/hcc/
python update_zone_region.py --project_id your-project-id
```
This will:

* Create or update the `zone_to_region.json` file with the zone-to-region mapping for your project.
* Update the `allowlisted_zones` in `metadata.display.yaml` for both `a3-megagpu-8g` (under `a3_mega_zone`) and `a3-ultragpu-8g` (under `a3_ultra_zone`) with the zones where these machine types are currently available.


## Notes
* The script uses the application default credentials for authentication. Make sure you've authenticated your environment using `gcloud auth application-default login`.
* The script currently supports updating allowlisted_zones for `a3-megagpu-8g` and `a3-ultragpu-8g` machine types. You can extend it to support other machine types by modifying the `update_blueprint_metadata` function.