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

test_prompts(sys.argv[1])
