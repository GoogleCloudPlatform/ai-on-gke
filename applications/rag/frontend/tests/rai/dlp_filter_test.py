import os
import unittest
import requests

from google.cloud import dlp_v2 as dlp
from google.api_core.exceptions import GoogleAPIError

# Convert the project id into a full resource id.
parent = os.environ.get('PROJECT_ID', 'NULL')


class DlpClientTest(unittest.TestCase):

    def setUp(self):
        os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = (
            "path/to/service_account_key.json"
        )
        self.client = dlp.DlpServiceClient()
        self.base_url = "https://dlp.googleapis.com/v2"

    def tearDown(self):
        pass

    @unittest.skipIf(parent == "NULL", "Parent project ID not set")
    def test_is_dlp_api_enabled(self):
        # Attempt to list info types.
        response = self.client.list_info_types(parent="en-US")

        # API should be enabled if the request succeeds.
        self.assertTrue(response)

    @unittest.skipIf(parent == "NULL", "Parent project ID not set")
    def test_error_during_api_call(self):
        # Make a request with an invalid API endpoint.
        try:
            self.client.list_info_types(parent="invalid_parent")
            self.fail("Expected GoogleAPIError to be raised.")
        except GoogleAPIError as e:
            # Expect an HTTP status code of 404 (Not Found).
            self.assertEqual(e.code, 404)

    def test_list_inspect_templates_from_parent(self):
        # Make a request with a valid parent project ID.
        response = self.client.list_inspect_templates(
            parent="projects/my-project-id"
        )

        # Check that the response contains a non-empty list of template names.
        self.assertGreater(len(response.inspect_templates), 0)

        # Verify the InspectTemplate structure.
        for template in response.inspect_templates:
            self.assertTrue(hasattr(template, "name"))
            self.assertTrue(hasattr(template, "inspect_config"))

    def test_get_inspect_templates_from_name(self):
        # Get a template from a known template name.
        response = self.client.get_inspect_template(
            name="projects/my-project-id/inspectTemplates/my-template"
        )

        # Verify the InspectTemplate structure.
        self.assertTrue(hasattr(response, "name"))
        self.assertTrue(hasattr(response, "inspect_config"))

    def test_list_deidentify_templates_from_parent(self):
        # Make a request with a valid parent project ID.
        response = self.client.list_deidentify_templates(
            parent="projects/my-project-id"
        )

        # Check that the response contains a non-empty list of template names.
        self.assertGreater(len(response.deidentify_templates), 0)

        # Verify the DeidentifyTemplate structure.
        for template in response.deidentify_templates:
            self.assertTrue(hasattr(template, "name"))
            self.assertTrue(hasattr(template, "deidentify_config"))

    def test_get_deidentify_templates_from_name(self):
        # Get a template from a known template name.
        response = self.client.get_deidentify_template(
            name="projects/my-project-id/deidentifyTemplates/my-template"
        )

        # Verify the DeidentifyTemplate structure.
        self.assertTrue(hasattr(response, "name"))
        self.assertTrue(hasattr(response, "deidentify_config"))

    @unittest.skipIf(
        parent == "NULL", "Parent project ID not set or inspect/deidentify disabled"
    )
    def test_inspect_content(self):
        # Set up input and paths for inspection and de-identification.
        input = "Some sample text to inspect."
        inspect_template_path = "projects/my-project-id/inspectTemplates/my-inspect-template"
        deidentify_template_path = "projects/my-project-id/deidentifyTemplates/my-deidentify-template"

        # Call the API and inspect the response.
        response = self.client.deidentify_content(
            parent=parent,
            inspect_config={"info_types": [{"name": "PHONE_NUMBER"}]},
            deidentify_config={
                "transformation": {
                    "primitive_transformation": {"replace_with_info_type": {"new_info_type": {"name": "EMAIL_ADDRESS"}}}
                }
            },
            item={"value": input},
        )
        # Check that the expected transformations were applied to the input text.
        expected_output = "REDACTED"  # Assuming phone numbers were deidentified
        self.assertEqual(response.item.value, expected_output)

    @unittest.skip("Network call to a public API endpoint")
    def test_network_api_call(self):
        # Make a GET request to the DLP API's base URL.
        response = requests.get(self.base_url)
        # Expect an HTTP status code of 200 (OK).
        self.assertEqual(response.status_code, 200)