""" image hash encode """
from argparse import ArgumentParser
import os
import sys
import math

def main():
    """general image hash by path"""
    parser = ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str, help='an path')
    args = parser.parse_args()
    path = args.path
    result = {}
    if os.path.isdir(path):
        tasks = [os.path.join(path, p) for p in os.listdir(path)]
        for task in tasks:
            result.update(check_file(task))
    else:
        result.update(check_file(path))
    print(result)


def check_file(path):
    """list image file"""
    extension = os.path.splitext(path)
    if (extension[1] in ['.jpg', '.png', '.webp', 'jpeg']) and os.path.exists(path):
        return {os.path.basename(path): extract_vit_features(path)}
    return {}

def extract_vit_features(path):
    """Extracts features from an image using a pre-trained model."""
    # contours.save(output_path)
    return 'translated'


if __name__ == '__main__':
    sys.exit(main())
