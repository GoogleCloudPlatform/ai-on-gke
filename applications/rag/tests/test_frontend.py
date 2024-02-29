import sys
import requests

def test_frontend_up(rag_frontend_url):
    r = requests.get(rag_frontend_url)
    r.raise_for_status()
    print("Rag frontend is up.")

hub_url = "http://" + sys.argv[1]

test_frontend_up(hub_url)
