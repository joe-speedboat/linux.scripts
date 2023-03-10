#!/bin/python3

# pip install --user openai
import openai
import argparse

# https://platform.openai.com/overview
openai.api_key = "asdfasdgfdfgfghdfghdfghdfgi"

def ask_gpt(prompt):
    model_engine = "text-davinci-002"
    response = openai.Completion.create(
        engine=model_engine,
        prompt=prompt,
        max_tokens=100,
        n=1,
        stop=None,
        temperature=0.7,
    )
    return response.choices[0].text.strip()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Query ChatGPT.')
    parser.add_argument('question', type=str, help='The question to ask ChatGPT.')
    args = parser.parse_args()

    question = args.question
    response = ask_gpt(question)
    print(response)
