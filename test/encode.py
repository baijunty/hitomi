import json;
import argparse;
import os;
import sys
import numpy as np
from imagededup.methods import CNN,AHash
def main():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str,help='an path')
    args = parser.parse_args()
    path=args.path
    extension=os.path.splitext(path)
    if(extension[1]=='.json'):
        return encode_json(path)
    elif (os.path.isdir(path)):
        cnn=CNN()
        map={}
        files=[i for i in os.listdir(path) if not os.path.split(i)[1].endswith('json')]
        for i in files:
            hash=cnn.encode_image(os.path.join(path,i))
            if not isinstance(hash, type(None)):
                map[i]=hash[0]
        hash=cnn.find_duplicates_to_remove(encoding_map=map,min_similarity_threshold=0.95)
        return print(json.dumps(hash))
    else:
        hash:str=AHash().encode_image(image_file=path)
        print(hash)
def encode_json(path:str):
    data=''
    with open(path,mode='r',encoding='utf-8') as f:
        data=json.load(f)
        f.close()
    if len(data)>0:
        return print(data) 
    else:
        return None
if __name__ == '__main__':
    sys.exit(main())