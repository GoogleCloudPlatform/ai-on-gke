import sys
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def test_frontend_up(rag_frontend_url):
    retry_strategy = Retry(
        total=5,  # Total number of retries
        backoff_factor=1,  # Waits 1 second between retries, then 2s, 4s, 8s...
        status_forcelist=[429, 500, 502, 503, 504],  # Status codes to retry on
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session = requests.Session()
    session.mount("http://", adapter)
    session.mount("https://", adapter)

    r = session.get(rag_frontend_url)
    r.raise_for_status()
    print("Rag frontend is up.")

    assert "Submit your query below." in r.content.decode('utf-8')
    assert "Data Loss Prevention" in r.content.decode('utf-8')
    assert "Text moderation" in r.content.decode('utf-8')

hub_url = "http://" + sys.argv[1]

test_frontend_up(hub_url)
