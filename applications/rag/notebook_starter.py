import requests
import sys

api_url = 'http://127.0.0.1:9443/hub/api'

token = sys.argv[1].strip()

r = requests.post(api_url + '/users/admin/server',
    headers = {
        'Authorization' : f'token {token}',
    },
    json={},
)

r.raise_for_status()
