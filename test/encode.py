import argparse;
import os;
import sys
import torch
from torchvision import transforms
from PIL import Image
import time
import json
import asyncio
from concurrent.futures import ThreadPoolExecutor
def main():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str,help='an path')
    args = parser.parse_args()
    path=args.path
    torch.device("cuda" if torch.cuda.is_available() else "cpu")
    result= []
    if os.path.isdir(path):
        pools = ThreadPoolExecutor(8)
        tasks=[pools.submit(check_file,os.path.join(path,p)) for p in os.listdir(path)]
        for task in tasks:
            result.append(task.result())
    else:
        return result.append(check_file(path))
    print(json.dumps(result))

def check_file(path):
    extension=os.path.splitext(path)
    if (extension[1] in ['.jpg','.png','.webp','jpeg']):
        return {os.path.basename(path):hash_image(path)}
    return {}
    
def hash_image(path,interpolation:transforms.InterpolationMode=transforms.InterpolationMode.BICUBIC)->int:
    image = Image.open(path)
    gray = transforms.Grayscale()
    image=gray(image)
    trans = transforms.Resize(size = (8,8),interpolation=interpolation)
    image = trans(image)
    pixels = list(image.getdata())
    acc=sum(pixels)
    avg=acc/64
    hash=0
    for (i,v) in enumerate(pixels):
        hash|= 1<<(63-i) if(v>=avg) else 0
    return hash

if __name__ == '__main__':
    sys.exit(main())