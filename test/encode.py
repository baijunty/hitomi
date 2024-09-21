""" image hash encode """
from argparse import ArgumentParser
import os
import sys
from concurrent.futures import ThreadPoolExecutor
# Import required packages
import cv2
import torch
import json
from ultralytics import YOLO
from transformers import ViTImageProcessor,AutoTokenizer,VisionEncoderDecoderModel
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from craft_text_detector import (
    load_craftnet_model,
    load_refinenet_model,
    get_prediction,
    file_utils
)

device = 'cuda' if torch.cuda.is_available() else 'cpu'
pretrained_model_name_or_path="kha-white/manga-ocr-base"
processor = ViTImageProcessor.from_pretrained(pretrained_model_name_or_path)
tokenizer = AutoTokenizer.from_pretrained(pretrained_model_name_or_path)
model = VisionEncoderDecoderModel.from_pretrained(pretrained_model_name_or_path).to(device)
yolo = YOLO('../best.pt').to(device=device)
request="""
 将以下对话文本从其原始语言翻译成“中文”。尽可能保持原文的语气和风格,只需返回原文和翻译键值对json:
文本：
---------
{}
---------
回复："""
refine_net = load_refinenet_model(cuda=True)
craft_net = load_craftnet_model(cuda=True)
def craft_text_bubble_detect(image):
    prediction_result = get_prediction(image=image,craft_net=craft_net,refine_net=refine_net,text_threshold=0.7,link_threshold=0.4,low_text=0.4,cuda=True,long_size=max(image.shape))
    result=[]
    for box in prediction_result["boxes"]:
        # result_rgb = file_utils.rectify_poly(image,box)
        # result_bgr = cv2.cvtColor(result_rgb, cv2.COLOR_RGB2BGR)
        x,y=box[0]
        x1,y1=box[2]
        result.append((x.item(),y.item(),x1.item(),y1.item()))
    return result

def detect_text_ocr(image):
    height, width = image.shape[:2]
    vert =height > width
    data = processor(image, return_tensors="pt").pixel_values.squeeze()
    data = model.generate(data[None].to(device), max_length=300)[0].cpu()
    data = tokenizer.decode(data, skip_special_tokens=True)
    data = data.replace(' ','')
    if vert:
        data=data.replace(':','..')
    return data

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
    print(result)

def check_file(path):
    """list image file"""
    extension=os.path.splitext(path)
    if (extension[1] in ['.jpg','.png','.webp','jpeg']) and os.path.exists(path):
        return {os.path.basename(path):extract_vit_features(path)}
    return {}

def is_fullwidth(char):
    return '\uFF00' <= char <= '\uFFFF'

def is_halfwidth(char):
    return '\u0020' <= char <= '\u007E' or '\u3000' <= char <= '\u303F'


def render_chinese_text(img, text,cols, color=(0, 0, 0)):
    if (isinstance(img, np.ndarray)):  # 判断是否OpenCV图片类型
        img = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    # 创建一个可以在给定图像上绘图的对象
    draw = ImageDraw.Draw(img)
    width,heigh=img.width,img.height
    text_size=36
    fontStyle = ImageFont.truetype(
        "/usr/share/fonts/google-noto-sans-mono-cjk-vf-fonts/NotoSansMonoCJK-VF.ttc", text_size, encoding="utf-8")
    _, _, w, h = draw.textbbox((0, 0), text[0], font=fontStyle)
    words = split_str(text,cols,h,heigh)
    deep=max([len(word) for word in words])
    top = 0
    # print(f'w {w} h {h} deep {deep} height {h*deep} at {width}:{heigh} word {words}')
    for i in range(deep):
        if len(words)>1:
            txt=''
            space=round((width-len(words)*w)/w)
            for word in reversed(words):
                if len(word)>i:
                    txt=txt + (f'{word[i]} ' if is_halfwidth(word[i]) else word[i])
                else:
                    txt=txt+'  '
            draw.text((max((width-len(words)*w)/2,0),top),txt , spacing=32, fill=color,font=fontStyle,language='zh-Hans')
        else:
            draw.text((max((width-w)/2,0),top),text[i],color,font=fontStyle,language='zh-Hans')
        top+=h
    return cv2.cvtColor(np.asarray(img), cv2.COLOR_RGB2BGR)

def split_str(text,cols,h,heigh):
    import re
    is_punct=False
    words=[]
    pov=0
    for i,t in enumerate(text):
        is_word=re.fullmatch(r"[\u4e00-\u9fa5|\w]",t) is None
        if (i-pov+1)*h>=heigh:
            words.append(text[pov:i])
            pov=i
        is_punct= is_word
    words.append(text[pov:])
    return words

def trasnlate_text(data):
    import requests
    result = []
    for d in data:
        resp=  requests.get(f'https://translate.googleapis.com/translate_a/single?client=gtx&dt=t&sl=ja&tl=zh&q={d}',timeout=50).json()[0][0][0].replace('…','...')
        result.append(resp)
    return result
    # resp=  requests.post('http://127.0.0.1:11434/api/generate',data=json.dumps({"model": "qwen2.5","prompt": request.format(data),"stream": False}),timeout=50).json()
    # resp=resp['response'].replace('…','...').replace('```','')
    # translated=json.loads(resp[4:] if resp.startswith('json') else resp)
    # print(translated)
    # if isinstance(translated,str):
    #     translated=translated.replace('\'','\"')
    #     translated=json.loads(translated)
    # if isinstance(translated,list):
    #     translated = [t['翻译'] for t in translated]
    # if isinstance(translated,dict):
    #     translated = [v if isinstance(v,str) else v['翻译'] for v in translated.values()]
    # print(f'input {data} result {translated}')
    # return translated

def render_text_to_image(text,croped):
    rects=craft_text_bubble_detect(croped)
    if len(rects)==0:
        return croped
    import functools
    import math
    from collections import Counter
    img = Image.fromarray(cv2.cvtColor(croped, cv2.COLOR_BGR2RGB))
    counter=Counter(list(img.getdata()))
    color=counter.most_common(1)[0][0]
    print('rects',text,rects)
    for rect in rects:
        text_img=croped[math.floor(rect[1]):math.ceil(rect[3]),math.floor(rect[0]):math.ceil(rect[2])]
        text_img[:]=color
    # rect = functools.reduce(lambda r1,r2:(min(r1[0],r2[0]),min(r1[1],r2[1]),max(r1[2],r2[2]),max(r1[3],r2[3])),rects)
    # text_img=croped[math.floor(rect[1]):math.ceil(rect[3]),math.floor(rect[0]):math.ceil(rect[2])]
    # text_img.fill(255)
    # text_img=render_chinese_text(text_img,text,len(rects))
    # cv2.rectangle(croped,(round(rect[0]),round(rect[1])),(round(rect[2]),round(rect[3])), (0, 255, 0), 2)
    # croped[math.floor(rect[1]):math.ceil(rect[3]),math.floor(rect[0]):math.ceil(rect[2])]=text_img
    return croped

def text_area_compare(b,b1):
    result=0
    if (b[3]-b[1])/2>b1[1] and (b[3]-b[1])/2<b1[3]:
        result = -1 if b[0]>b1[0] else 1
    else:
        result = b[1]-b1[1]
    return result

def is_same_line(ele,box):
    return (box[1]>ele[1] and box[1]<ele[3]) or (ele[1]>box[1] and ele[1]<box[3])

def area_conflict(b1, b2):
    return not (b1[2] < b2[0] or b1[3] < b2[1] or b1[0] > b2[2] or b1[1] > b2[3])

def sort_areaes(boxes):
    result=[]
    while len(boxes)>0:
        box=boxes.pop()
        exist=False
        for element in result:
            for ele in element:
                if is_same_line(ele,box):
                    exist=True
                    break
            if exist:
                conficted_index = -1
                for i,ele in enumerate(element):
                    if area_conflict(ele,box):
                        conficted_index = i
                        break
                if conficted_index<0:
                    element.append(box)
                else:
                    element[conficted_index]=(min(element[conficted_index][0],box[0]),min(element[conficted_index][1],box[1]),max(element[conficted_index][2],box[2]),max(element[conficted_index][3],box[3]))
                    # x,y,x1,y1=element[conficted_index]
                    # if x>box[0]:
                    #     element[conficted_index]=(max(x,box[2]),y,x1,y1)
                    #     element.append((box[0],box[1],min(box[2],x),box[3]))
                    # else:
                    #     element[conficted_index]=(x,y,min(x1,box[0]),y1)
                    #     element.append((max(box[0],x1),box[1],box[2],box[3]))
                break
        if not exist:
            result.append([box])
    sort_box=[]
    result.sort(key=lambda l:l[0][1])
    from functools import cmp_to_key
    for r in result:
        re=sorted(r,key=cmp_to_key(mycmp=text_area_compare))
        sort_box.extend(re)
    return sort_box
        

def extract_vit_features(path):
    """Extracts features from an image using a pre-trained model."""
    img = cv2.imread(path)
    # img=Image.open(path)
    boxes=yolo.predict(path)[0]
    # output_path = os.path.splitext(os.path.basename(path))[0] +'_boxes.jpg'
    # Image.fromarray(result.plot()).save(output_path)
    boxes = [[round(x.item()) for x in cnt.boxes[0].xyxy[0]] for cnt in boxes if cnt.boxes[0].conf>=0.8]
    boxes=sort_areaes(boxes)
    text_rect = {}
    for cnt in boxes:
        x,y,x1,y1=cnt
        # coords=[round(x.item()) for x in cnt.boxes[0].xyxy[0]]
        # croped= img.crop(coords).convert('RGB')
        croped= img[y:y1,x:x1]
        data=detect_text_ocr(croped)
        text_rect[data]=(x,y,x1,y1)
    translated=trasnlate_text(list(text_rect.keys()))
    for i,cnt in enumerate(text_rect.values()):
        x,y,x1,y1=cnt
        croped= img[y:y1,x:x1]
        render_text_to_image(translated[i],croped)
    output_path = os.path.splitext(os.path.basename(path))[0] +'_processed.jpg'
    cv2.imwrite(output_path, img)
    # contours.save(output_path)
    return translated

if __name__ == '__main__':
    sys.exit(main())
