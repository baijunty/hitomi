""" image hash encode """
from argparse import ArgumentParser
import os
import sys
import requests
def main():
    """general image hash by path"""
    parser = ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str, help='an path')
    args = parser.parse_args()
    path = args.path
    result = {}
    # if os.path.isdir(path):
    #     tasks = [os.path.join(path, p) for p in os.listdir(path)]
    #     for task in tasks:
    #         result.update(check_file(task))
    # else:
    #     result.update(check_file(path))
    print(result)


def check_file(path):
    """list image file"""
    with open(path, 'r') as f:
        lines=[line.strip() for line in f.readlines()]
        import json
        resp=requests.post('http://localhost:11434/api/embed', data=json.dumps({'model': 'hf.co/second-state/gte-Qwen2-1.5B-instruct-GGUF:Q5_K_M','input':lines})).json()
        print(resp.keys())
        import numpy as np
        from numpy.linalg import norm
        embeddings=resp['embeddings']
        target = embeddings[0]
        similarities = [np.dot(target,item)/(norm(target)*norm(item)) for item in embeddings[1:]]
        similarities = {lines[i+1]:similarity.item() for i,similarity in enumerate(similarities)}
        return similarities
    return {}

def extract_vit_features(path):
    """Extracts features from an image using a pre-trained model."""
    # contours.save(output_path)
    return path


if __name__ == '__main__':
    sys.exit(main())
