# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from jupyterhub.handlers import BaseHandler
from jupyterhub.auth import Authenticator
from jupyterhub.utils import url_path_join
import requests
import logging
from tornado import web
from traitlets import Unicode
from urllib import parse
from google.auth.transport import requests
from google.oauth2 import id_token
from googleapiclient import discovery
import google.auth


def list_backend_services_ids(project_id, keyword):
    credentials, _ = google.auth.default()
    service = discovery.build('compute', 'v1', credentials=credentials)
    request = service.backendServices().list(project=project_id)
    response = request.execute()

    filtered_service_ids = [
        service['id'] for service in response.get('items', [])
        if keyword.lower() in service['name'].lower()
    ]

    return filtered_service_ids


class IAPUserLoginHandler(BaseHandler):
    def get(self):
        header_name = self.authenticator.header_name

        auth_header_content = self.request.headers.get(header_name, "") if header_name else None

        # Extract project ID, namespace, and backend config name from the authenticator
        project_id = self.authenticator.project_id
        namespace = self.authenticator.namespace
        service_name = self.authenticator.service_name
        print("Project ID:", project_id)
        print("Namespace:", namespace)
        print("Backend Config Name:", service_name)

        # Construct the keyword from namespace and backend config name
        keyword = namespace + "-" + service_name
        print("Keyword:", keyword)

        # List GCP backend services IDs based on the project ID and keyword
        gcp_backend_services_ids = list_backend_services_ids(project_id, keyword)
        print("GCP Backend Services IDs:", gcp_backend_services_ids)

        # Construct expected audiences from the GCP backend services IDs
        expected_audiences = [f"/projects/{self.authenticator.project_number}/global/backendServices/{service_id}" for service_id in gcp_backend_services_ids]
        print("Expected Audiences:", expected_audiences)

        if self.authenticator.header_name != "X-Goog-IAP-JWT-Assertion":
            raise web.HTTPError(400, 'X-Goog-IAP-JWT-Assertion is the only accepted Header')
        elif bool(auth_header_content) == 0:
            raise web.HTTPError(400, 'Can not verify the IAP authentication content.')
        else:
            _, user_email, err = validate_iap_jwt(
                auth_header_content,
                expected_audiences
            )
            if err:
                raise Exception(f'Ran into error: {err}')
            else:
                logging.info(f'Successfully validated!')

        username = user_email.lower().split("@")[0]
        user = self.user_from_username(username)

        self.set_login_cookie(user)
        self.redirect(url_path_join(self.hub.server.base_url, 'home'))

class GCPIAPAuthenticator(Authenticator):
    """
    Accept the authenticated JSON Web Token from IAP Login.
    Used by the JupyterHub as the Authentication class
        The get_handlers is how JupyterHub know how to handle auth
    """
    header_name = Unicode(
        config=True,
        help="""HTTP/HTTPS header to inspect for the authenticated JWT.""")

    cookie_name = Unicode(
        config=True,
        help="""The name of the cookie field used to specify the JWT token""")

    param_name = Unicode(
        config=True,
        help="""The name of the query parameter used to specify the JWT token""")

    project_id = Unicode(
        default_value='',
        config=True,
        help="""Expected project_id""")

    project_number = Unicode(
        default_value='',
        config=True,
        help="""Expected project_number""")

    namespace = Unicode(
        default_value='',
        config=True,
        help="""Expected namespace""")

    service_name = Unicode(
        default_value='',
        config=True,
        help="""Expected backend_config_name""")

    secret = Unicode(
        config=True,
        help="""Shared secret key for signing JWT token""")

    def get_handlers(self, app):
        return [(r'login', IAPUserLoginHandler)]

def validate_iap_jwt(iap_jwt, expected_audiences):
    """Validate an IAP JWT.

    Args:
      iap_jwt: The contents of the X-Goog-IAP-JWT-Assertion header.
      expected_audiences: The Signed Header JWT audiences. See
          https://cloud.google.com/iap/docs/signed-headers-howto
          for details on how to get this value.

    Returns:
      (user_id, user_email, error_str).
    """

    try:
        decoded_jwt = id_token.verify_token(
            iap_jwt,
            requests.Request(),
            audience=expected_audiences,
            certs_url="https://www.gstatic.com/iap/verify/public_key",
        )
        return (decoded_jwt["sub"], decoded_jwt["email"], "")
    except Exception as e:
        return (None, None, f"JWT validation error {e}")
