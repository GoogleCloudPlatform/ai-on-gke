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

class IAPUserLoginHandler(BaseHandler):
    def get(self):
        header_name = self.authenticator.header_name
        
        auth_header_content = self.request.headers.get(header_name, "") if header_name else None
        expected_audience = self.authenticator.expected_audience
    
        if self.authenticator.header_name != "X-Goog-IAP-JWT-Assertion":
            raise web.HTTPError(400, 'X-Goog-IAP-JWT-Assertion is the only accepted Header')
        elif bool(auth_header_content) == 0:
            raise web.HTTPError(400, 'Can not verify the IAP authentication content.')
        else:
            _, user_email, err = validate_iap_jwt(
                auth_header_content,
                expected_audience
            )
            if err:
                raise Exception(f'Ran into error: {err}')
            else:
                logging.info(f'Successfully validated!')
        
        username = user_email.lower()
        user = self.user_from_username(username)

        self.set_login_cookie(user)
        self.redirect(url_path_join(self.hub.server.base_url, 'home'))
        
class GCPIAPAuthenticator(Authenticator):
    """
    Accept the authenticated JSON Web Token from IAP Login.
    Used by the Jupyterhub as the Authentication class
        The get_handlers is how Jupyterhub know how to handle auth
    """
    header_name = Unicode(
        config=True,
        help="""HYYP header to inspect for the authenticated JWT.""")
    
    cookie_name = Unicode(
        config=True,
        help="""The name of the cookie field used to specify the JWT token""")

    param_name = Unicode(
        config=True,
        help="""The name of the query parameter used to specify the JWT token""")
    
    expected_audience = Unicode(
        default_value='',
        config=True,
        help="""Expected Audience of the authenication JWT""")
    
    secret = Unicode(
        config=True,
        help="""Shared secret key for signing JWT token""")

    def get_handlers(self, app):
        return [(r'login', IAPUserLoginHandler)]

def validate_iap_jwt(iap_jwt, expected_audience):
    """Validate an IAP JWT.

    Args:
      iap_jwt: The contents of the X-Goog-IAP-JWT-Assertion header.
      expected_audience: The Signed Header JWT audience. See
          https://cloud.google.com/iap/docs/signed-headers-howto
          for details on how to get this value.

    Returns:
      (user_id, user_email, error_str).
    """

    try:
        decoded_jwt = id_token.verify_token(
            iap_jwt,
            requests.Request(),
            audience=expected_audience,
            certs_url="https://www.gstatic.com/iap/verify/public_key",
        )
        return (decoded_jwt["sub"], decoded_jwt["email"], "")
    except Exception as e:
        return (None, None, f"JWT validation error {e}")
