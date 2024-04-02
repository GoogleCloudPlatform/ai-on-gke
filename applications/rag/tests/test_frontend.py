import sys
import requests

def test_frontend_up(rag_frontend_url):
    r = requests.get(rag_frontend_url)
    r.raise_for_status()
    print("Rag frontend is up.")

    assert "Submit your query below." in r.content.decode('utf-8')
    assert "Data Loss Prevention" in r.content.decode('utf-8')
    assert "Text moderation" in r.content.decode('utf-8')

hub_url = "http://" + sys.argv[1]

test_frontend_up(hub_url)
