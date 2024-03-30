""" image hash encode """
from argparse import ArgumentParser
import os
import sys
import json
from concurrent.futures import ThreadPoolExecutor
import torch
from torchvision import transforms
from torchvision.transforms import InterpolationMode
from PIL import Image
def main():
    """general image hash by path"""
    parser = ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str,help='an path')
    args = parser.parse_args()
    path=args.path
    torch.device("cuda" if torch.cuda.is_available() else "cpu")
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
        return {os.path.basename(path):hash_image(path)}
    return {}

def hash_image(path,interpolation:InterpolationMode=InterpolationMode.BICUBIC)->int:
    """general image hash"""
    image = Image.open(path)
    gray = transforms.Grayscale()
    image=gray(image)
    trans = transforms.Resize(size = (8,8),interpolation=interpolation)
    image = trans(image)
    pixels = list(image.getdata())
    acc=sum(pixels)
    avg=acc/64
    h=0
    for (i,v) in enumerate(pixels):
        h|= 1<<(63-i) if(v>=avg) else 0
    return h

if __name__ == '__main__':
    sys.exit(main())
