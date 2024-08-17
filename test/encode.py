""" image hash encode """
from argparse import ArgumentParser
import os
import sys
import json
from concurrent.futures import ThreadPoolExecutor
from transformers import ViTFeatureExtractor, ViTModel
import torch
from PIL import Image

model = ViTModel.from_pretrained('microsoft/resnet-50')
feature_extractor = ViTFeatureExtractor.from_pretrained('microsoft/resnet-50')
model.eval()

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
    img = Image.open(path)
    inputs = feature_extractor(images=img, return_tensors="pt")

    with torch.no_grad():
        outputs = model(**inputs)
        # 获取最后一层的[CLS] token特征作为图像特征
        features = outputs.last_hidden_state[:, 0, :].numpy()
    return features.tolist()

if __name__ == '__main__':
    sys.exit(main())
