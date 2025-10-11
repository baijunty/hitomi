# hitomi
工口漫画网站[hitomi](https://hitomi.la/)后端下载管理

- flutter前端
[ayaka](https://github.com/baijunty/ayaka)

## 功能特性
- 支持从hitomi.la网站下载漫画
- 本地数据库存储漫画信息
- 图片特征识别和标签管理
- 多平台支持（Windows, macOS, Linux）
- 支持批量下载和管理

## Docker部署
使用Docker可以轻松部署此应用：

1. 构建Docker镜像：
   ```bash
   docker build -t hitomi .
   ```

2. 运行容器：
   ```bash
   docker run -p 7890:7890 hitomi
   ```

3. 访问服务：
   在浏览器中访问 `http://localhost:7890`

## 支持功能
- [x] 漫画信息获取与解析
- [x] 漫画图片下载
- [x] 本地数据库存储
- [x] 图片特征提取与标签匹配
- [x] 多平台支持
- [x] 批量操作支持

[MIT](https://choosealicense.com/licenses/mit/)

Copyright (c) 

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
