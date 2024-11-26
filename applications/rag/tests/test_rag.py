import json
import sys
import requests

def test_prompts(prompt_url):
    testcases = [
        {
            "prompt": "List the cast of Squid Game",
            "expected_context": "This is a TV Show in  called Squid Game added at September 17, 2021 whose director is  and with cast: Lee Jung-jae, Park Hae-soo, Wi Ha-jun, Oh Young-soo, Jung Ho-yeon, Heo Sung-tae, Kim Joo-ryoung, Tripathi Anupam, You Seong-joo, Lee You-mi released at 2021. Its rating is: TV-MA. Its duration is 1 Season. Its description is Hundreds of cash-strapped players accept a strange invitation to compete in children's games. Inside, a tempting prize awaits — with deadly high stakes..",
            "expected_substrings": ["Lee Jung-jae", "Park Hae-soo", "Wi Ha-jun", "Oh Young-soo", "Jung Ho-yeon", "Heo Sung-tae", "Kim Joo-ryoung", "Tripathi Anupam", "You Seong-joo", "Lee You-mi"],
        },
        {
            "prompt": "When was Squid Game released?",
            "expected_context": "This is a TV Show in  called Squid Game added at September 17, 2021 whose director is  and with cast: Lee Jung-jae, Park Hae-soo, Wi Ha-jun, Oh Young-soo, Jung Ho-yeon, Heo Sung-tae, Kim Joo-ryoung, Tripathi Anupam, You Seong-joo, Lee You-mi released at 2021. Its rating is: TV-MA. Its duration is 1 Season. Its description is Hundreds of cash-strapped players accept a strange invitation to compete in children's games. Inside, a tempting prize awaits — with deadly high stakes..",
            "expected_substrings": ["September 17, 2021"],
        },
        {
            "prompt": "What is the rating of Squid Game?",
            "expected_context": "This is a TV Show in  called Squid Game added at September 17, 2021 whose director is  and with cast: Lee Jung-jae, Park Hae-soo, Wi Ha-jun, Oh Young-soo, Jung Ho-yeon, Heo Sung-tae, Kim Joo-ryoung, Tripathi Anupam, You Seong-joo, Lee You-mi released at 2021. Its rating is: TV-MA. Its duration is 1 Season. Its description is Hundreds of cash-strapped players accept a strange invitation to compete in children's games. Inside, a tempting prize awaits — with deadly high stakes..",
            "expected_substrings": ["TV-MA"],
        },
        {
            "prompt": "List the cast of Avatar: The Last Airbender",
            "expected_context": "This is a TV Show in United States called Avatar: The Last Airbender added at May 15, 2020 whose director is  and with cast: Zach Tyler, Mae Whitman, Jack De Sena, Dee Bradley Baker, Dante Basco, Jessie Flower, Mako Iwamatsu released at 2007. Its rating is: TV-Y7. Its duration is 3 Seasons. Its description is Siblings Katara and Sokka wake young Aang from a long hibernation and learn he's an Avatar, whose air-bending powers can defeat the evil Fire Nation..",
            "expected_substrings": ["Zach Tyler", "Mae Whitman", "Jack De Sena", "Dee Bradley Baker", "Dante Basco", "Jessie Flower", "Mako Iwamatsu"],
        },
        {
            "prompt": "When was Avatar: The Last Airbender added on Netflix?",
            "expected_context": "This is a TV Show in United States called Avatar: The Last Airbender added at May 15, 2020 whose director is  and with cast: Zach Tyler, Mae Whitman, Jack De Sena, Dee Bradley Baker, Dante Basco, Jessie Flower, Mako Iwamatsu released at 2007. Its rating is: TV-Y7. Its duration is 3 Seasons. Its description is Siblings Katara and Sokka wake young Aang from a long hibernation and learn he's an Avatar, whose air-bending powers can defeat the evil Fire Nation..",
            "expected_substrings": ["May 15, 2020"],
        },
        {
            "prompt": "What is the rating of Avatar: The Last Airbender?",
            "expected_context": "This is a TV Show in United States called Avatar: The Last Airbender added at May 15, 2020 whose director is  and with cast: Zach Tyler, Mae Whitman, Jack De Sena, Dee Bradley Baker, Dante Basco, Jessie Flower, Mako Iwamatsu released at 2007. Its rating is: TV-Y7. Its duration is 3 Seasons. Its description is Siblings Katara and Sokka wake young Aang from a long hibernation and learn he's an Avatar, whose air-bending powers can defeat the evil Fire Nation..",
            "expected_substrings": ["TV-Y7"],
        },
    ]

    for testcase in testcases:
        prompt = testcase["prompt"]
        expected_context = testcase["expected_context"]
        expected_substrings = testcase["expected_substrings"]

        print(f"Testing prompt: {prompt}")
        data = {"prompt": prompt}
        json_payload = json.dumps(data)

        headers = {'Content-Type': 'application/json'}
        response = requests.post(prompt_url, data=json_payload, headers=headers)
        response.raise_for_status()

        response = response.json()
        context = response['response']['context']
        text = response['response']['text']
        user_prompt = response['response']['user_prompt']

        print(f"Reply: {text}")

        assert user_prompt == prompt, f"unexpected user prompt: {user_prompt} != {prompt}"
        assert context == expected_context, f"unexpected context: {context} != {expected_context}"

        for substring in expected_substrings:
            assert substring in text, f"substring {substring} not in response:\n {text}"

def test_prompts_nlp(prompt_url):
    testcases = [
        {
            "prompt": "List the cast of Squid Game",
            "nlpFilterLevel": "0",
            "expected_context": "This is a TV Show in  called Squid Game added at September 17, 2021 whose director is  and with cast: Lee Jung-jae, Park Hae-soo, Wi Ha-jun, Oh Young-soo, Jung Ho-yeon, Heo Sung-tae, Kim Joo-ryoung, Tripathi Anupam, You Seong-joo, Lee You-mi released at 2021. Its rating is: TV-MA. Its duration is 1 Season. Its description is Hundreds of cash-strapped players accept a strange invitation to compete in children's games. Inside, a tempting prize awaits — with deadly high stakes..",
            "expected_substrings": ["Lee Jung-jae", "Park Hae-soo", "Wi Ha-jun", "Oh Young-soo", "Jung Ho-yeon", "Heo Sung-tae", "Kim Joo-ryoung", "Tripathi Anupam", "You Seong-joo", "Lee You-mi"],
        },
        {
            "prompt": "Which movie has a building that blows up?",
            "nlpFilterLevel": "0",
            "expected_context": "This is a Movie in United States called Oklahoma City added at April 19, 2017 whose director is Barak Goodman and with cast:  released at 2017. Its rating is: TV-14. Its duration is 102 min. Its description is Domestic terrorist Timothy McVeigh's bomb attack on an Oklahoma City federal building in 1995 is chronicled in this examination of the shocking event..",
            "expected_substrings": ["The movie \"Oklahoma City\" released in 2017, directed by Barak Goodman, and starring a cast, depicts the bombing of an Oklahoma City federal building in 1995. The building that blows up in the movie is the Alfred P. Murrah Federal Building."],
        },
        {
            "prompt": "Which movie has a building that blows up?",
            "nlpFilterLevel": "50",
            "expected_context": "This is a Movie in United States called Oklahoma City added at April 19, 2017 whose director is Barak Goodman and with cast:  released at 2017. Its rating is: TV-14. Its duration is 102 min. Its description is Domestic terrorist Timothy McVeigh's bomb attack on an Oklahoma City federal building in 1995 is chronicled in this examination of the shocking event..",
            "expected_substrings": ["The response is deemed inappropriate for display."],
        },
        {
            "prompt": "List the cast of Squid Game",
            "nlpFilterLevel": "100",
            "expected_context": "This is a TV Show in  called Squid Game added at September 17, 2021 whose director is  and with cast: Lee Jung-jae, Park Hae-soo, Wi Ha-jun, Oh Young-soo, Jung Ho-yeon, Heo Sung-tae, Kim Joo-ryoung, Tripathi Anupam, You Seong-joo, Lee You-mi released at 2021. Its rating is: TV-MA. Its duration is 1 Season. Its description is Hundreds of cash-strapped players accept a strange invitation to compete in children's games. Inside, a tempting prize awaits — with deadly high stakes..",
            "expected_substrings": ["The response is deemed inappropriate for display."],
        }
    ]

    for testcase in testcases:
        prompt = testcase["prompt"]
        nlpFilterLevel = testcase["nlpFilterLevel"]
        expected_context = testcase["expected_context"]
        expected_substrings = testcase["expected_substrings"]

        print(f"Testing prompt: {prompt}")
        data = {"prompt": prompt, "nlpFilterLevel": nlpFilterLevel}
        json_payload = json.dumps(data)

        headers = {'Content-Type': 'application/json'}
        response = requests.post(prompt_url, data=json_payload, headers=headers)
        response.raise_for_status()

        response = response.json()
        context = response['response']['context']
        text = response['response']['text']
        user_prompt = response['response']['user_prompt']

        print(f"Reply: {text}")

        assert user_prompt == prompt, f"unexpected user prompt: {user_prompt} != {prompt}"
        assert context == expected_context, f"unexpected context: {context} != {expected_context}"

        for substring in expected_substrings:
            assert substring in text, f"substring {substring} not in response:\n {text}"

def test_prompts_dlp(prompt_url):
    testcases = [
        {
            "prompt": "who worked with Robert De Niro and name one film they collaborated?",
            "inspectTemplate": "projects/gke-ai-eco-dev/locations/global/inspectTemplates/DO-NOT-DELETE-e2e-test-inspect-template",
            "deidentifyTemplate": "projects/gke-ai-eco-dev/locations/global/deidentifyTemplates/DO-NOT-DELETE-e2e-test-de-identify-template",
            "expected_context": "This is a Movie in United States called GoodFellas added at January 1, 2021 whose director is Martin Scorsese and with cast: Robert De Niro, Ray Liotta, Joe Pesci, Lorraine Bracco, Paul Sorvino, Frank Sivero, Tony Darrow, Mike Starr, Frank Vincent, Chuck Low released at 1990. Its rating is: R. Its duration is 145 min. Its description is Former mobster Henry Hill recounts his colorful yet violent rise and fall in a New York crime family – a high-rolling dream turned paranoid nightmare..",
            "expected_substrings": ["[PERSON_NAME] has worked with many talented actors and directors throughout his career. One film he collaborated with [PERSON_NAME] is \"GoodFellas,\" which was released in 1990. In this movie, [PERSON_NAME] played the role of [PERSON_NAME], a former mobster who recounts his rise and fall in a New York crime family."],
        },
    ]

    for testcase in testcases:
        prompt = testcase["prompt"]
        inspectTemplate = testcase["inspectTemplate"]
        deidentifyTemplate = testcase["deidentifyTemplate"]
        expected_context = testcase["expected_context"]
        expected_substrings = testcase["expected_substrings"]

        print(f"Testing prompt: {prompt}")
        data = {"prompt": prompt, "inspectTemplate": inspectTemplate, "deidentifyTemplate": deidentifyTemplate}
        json_payload = json.dumps(data)

        headers = {'Content-Type': 'application/json'}
        response = requests.post(prompt_url, data=json_payload, headers=headers)
        response.raise_for_status()

        response = response.json()
        context = response['response']['context']
        text = response['response']['text']
        user_prompt = response['response']['user_prompt']

        print(f"Reply: {text}")

        assert user_prompt == prompt, f"unexpected user prompt: {user_prompt} != {prompt}"
        assert context == expected_context, f"unexpected context: {context} != {expected_context}"

        for substring in expected_substrings:
            assert substring in text, f"substring {substring} not in response:\n {text}"

prompt_url = sys.argv[1]
test_prompts(prompt_url)
test_prompts_nlp(prompt_url)
test_prompts_dlp(prompt_url)
