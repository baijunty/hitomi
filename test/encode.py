
import argparse;
import os;
import sys
import torch  
import matplotlib.pyplot as plot  
import numpy as np  
from torchvision import transforms  
from PIL import Image 
def main():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str,help='an path')
    args = parser.parse_args()
    path=args.path
    extension=os.path.splitext(path)
    if (extension[1] in ['.jpg','.png','.webp','jpeg']):
        image = Image.open(path)
        torch.device("cuda" if torch.cuda.is_available() else "cpu")
        print(image.size)
        transforms = transforms.Resize(size = (450,650))
        image = transforms(image)
        print(image.size)
        return print(path)
    else:
        print(f'unknow {path} {extension[1]}')

if __name__ == '__main__':
    sys.exit(main())