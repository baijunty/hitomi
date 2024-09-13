""" image hash encode """
from argparse import ArgumentParser
import os
import sys
import json
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
from ultralytics import YOLO
model = YOLO("../wd-swinv2-tagger-v3-hf/yolov10b.pt")

def main():
    """general image hash by path"""
    parser = ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str,help='an path')
    args = parser.parse_args()
    path=args.path
    result= {}
    if os.path.isdir(path):
        pools = ThreadPoolExecutor(8)
        tasks=[pools.submit(check_file,os.path.join(path,p)) for p in os.listdir(path)]
        for task in tasks:
            result.update(task.result())
    else:
        result.update(check_file(path))
    print(json.dumps(result))

def check_file(path):
    """list image file"""
    extension=os.path.splitext(path)
    if (extension[1] in ['.jpg','.png','.webp','jpeg']):
        return {os.path.basename(path):extract_vit_features(path)}
    return {}

def extract_vit_features(path):
    results = model(path)
    return [r.names for r in results]

if __name__ == '__main__':
    sys.exit(main())
