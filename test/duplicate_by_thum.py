from imagededup.methods import CNN
import os
import io
import sys
imgs='/mnt/ssd/photos'
img_extension=['jpg','jpeg','webp','png','bmp']
ite=filter(lambda d:os.path.isdir(os.path.join(imgs,d)), os.listdir(imgs))
ite=map(lambda d:os.listdir(os.path.join(imgs,d)), ite)
ite=filter(lambda d:len(d)>0 and any(os.path.splitext(f)[1][1:] in img_extension for f in d), ite)
ite=map(lambda d: next(os.path.join(d,f) for f in d if os.path.splitext(f)[1][1:] in img_extension), ite)
ite=list(ite)[0:20]
for f in ite:
    print(f)
