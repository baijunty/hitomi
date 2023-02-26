import json;
import argparse;
def main():
    parser = argparse.ArgumentParser(description='Process some integers.')
    parser.add_argument('path', metavar='p', type=str,help='an path')
    args = parser.parse_args()
    path=args.path
    data=''
    with open(path,mode='r',encoding='utf-8') as f:
        data=json.load(f)
        f.close()
    with open(path,mode='w+',encoding='utf-8') as f:
        if(isinstance(data, dict)):
            data=json.dump(data, f,ensure_ascii=False)
        else:
            f.write(data)
        f.close()
if __name__ == '__main__':
    main()