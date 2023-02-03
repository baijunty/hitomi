from PIL import Image
import imagehash
hash = imagehash.average_hash(Image.open('test3.webp'))
hash1=imagehash.average_hash(Image.open('test4.webp'))
print(hash1-hash)