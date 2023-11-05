from imagededup.methods import CNN,AHash
import os
import PIL
import io
import sys
import argparse;
img_extension=['jpg','jpeg','webp','png','bmp']
def main():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str,help='an path')
    args = parser.parse_args()
    path=args.path
    if(os.listdir(path)):
        listDir(path)
    
    
def listDir(path:dir):
    cnn=CNN()
    map={}
    length=0
    for f in os.listdir(path):
        realPath=os.path.join(path,f)
        extension=os.path.splitext(realPath)[1][1:]
        if(os.path.isdir(realPath)):
            listDir(realPath)
        elif(extension in img_extension):
            hash=cnn.encode_image(realPath)
            map[f]=hash[0]
            length+=1
    delfs = cnn.find_duplicates_to_remove(encoding_map=map)
    rate=len(delfs)/length
    print(f'del  {delfs} len is {len(delfs)} and total {length} rate {rate}')
    if(rate>0.3):
        for f in delfs:
            realPath=os.path.join(path,f)
            print('del '+realPath)
            os.remove(realPath)
if __name__ == '__main__':
    sys.exit(main())