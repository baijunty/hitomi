// ==UserScript==
// @name        downloader - hitomi.la
// @namespace   Violentmonkey Scripts
// @match       https://hitomi.la/*
// @grant       GM_xmlhttpRequest
// @grant       GM_setValue
// @grant       GM_getValue
// @grant       GM_addStyle
// @version     1.0
// @author      zhangsan
// @description 2023/12/10 21:45:07
// ==/UserScript==
(async function () {
    'use strict';
    GM_addStyle(`.dialog-box {
        position: fixed;
        margin: 0;
        padding: 0;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        border: none 0;
        background-color: rgba(0, 0, 0, 0.8);
      }
      .dialog {
        display: block;
        position: fixed;
        top: 50%;
        left: 50%;
        transform: translate(-50%, -50%);
        background-color: #fff;
        padding: 20px;
        border-radius: 5px;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
      }
      .button {
        background-color: #04aa6d;
        border: none;
        color: white;
        padding: 5px 10px;
        text-align: center;
        text-decoration: none;
        display: center;
        font-size: 12px;
        margin: 4px 2px;
        cursor: pointer;
        margin-left: 10px;
      }
      .right-frame {
        position: absolute;
        transform: translateY(-50%);
        background-color: #777;
        height: auto;
        right: 16px;
        color: white;
        padding: 10px 20px;
        border-radius: 5px;
        opacity: 1;
        max-width:${(window.screen.width - 1060) / 2}px;
        left:${document.querySelector('.container').offsetLeft + 1060}px;
    }
    .bottom-dialog{
        position: fixed;
        bottom: 20px;
        left: 50%;
        transform: translateX(-50%);
        background-color: #555;
        color: #555;
        padding: 10px 20px;
        border-radius: 5px;
        opacity: 1;
        animation: fade-in 0.3s ease-in-out;
    }
    .bottom-dialog.remove {
        animation: fade-out 0.5s ease-in-out;
        animation-fill-mode: forwards;
      }
    @keyframes fade-in {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    @keyframes fade-out {
      from { opacity: 1; }
      to { opacity: 0; }
    }
    .label {
      width:120px;
      background-color:green;
      color:white;
      text-align:right
    }

    .table {
        width:100%;
        border-collapse: collapse;
        border: 2px solid white;
        font-family: sans-serif;
        font-size: 0.8rem;
        letter-spacing: 1px;
    }
    .table caption {
        color:white;
        padding: 10px;
        text-align:center;
        font-weight: bold;
    }
    .table th,td {
      border: 1px solid white;
      padding: 8px 10px;
    }
    .item {
      margin-left:8px;
      margin-top:8px;
      min-width:50px;
      color:blue;
      border:1px solid;
      text-align: center;
      border-block-color:blue;
    }
    .tags {
        display: flex;
        flex-wrap: wrap;

      }

      .tags li {
        margin: 5px;
        padding: 5px 10px;
        background-color:#999999;
        border: 1px solid #ccc;
        border-radius: 5px;
      }

      .tags li a {
        padding: 4px;
        background-color:transparent;
        color:
        border-radius: 4px;
      }

      .hide{
        display:none;
      }
      `)
    var remoteUrl = GM_getValue('hitomi_la_remote_url', '')
    async function fetchRemote({ path, data = null, get = true, baseHttp = remoteUrl }) {
        let url = baseHttp + path
        console.log(url)
        return new Promise(function (resolve) {
            GM_xmlhttpRequest({
                method: get ? 'GET' : 'POST',
                responseType: 'json',
                timeout: 30000, // 3秒超时
                url: url,
                data: data,
                headers: {   // If not specifie
                    "referer": window.document.location.href          // If not specified, browser defaults will be used.
                },
                onload: function (res) {
                    if (res.status == 200) {
                        resolve(res.responseText)
                    } else {
                        showToast('http error ' + res.status);
                        console.log(res)
                    }
                }

            });
        })
    }
    let manga = document.getElementsByClassName('gallery-content');
    var token = GM_getValue('hitomi_la_remote_token', '')
    var saveExculdes = GM_getValue('hitomi_la_remote_excludes_tags', '')
    var excludes = []
    if (saveExculdes.length == 0 && remoteUrl.length) {
        saveExculdes = await fetchRemote({ path: 'excludes', data: JSON.stringify({ auth: token }), get: false })
        excludes = JSON.parse(saveExculdes)
        GM_setValue('hitomi_la_remote_excludes_tags', saveExculdes)
    } else if (remoteUrl.length) {
        excludes = JSON.parse(saveExculdes)
    }
    function showToast(msg, duration) {
        duration = isNaN(duration) ? 3000 : duration;
        var m = document.createElement('div');
        m.innerHTML = msg;
        m.className = "bottom-dialog"
        m.style.cssText = "transition: opacity 0.3s ease-in-out;color:white"
        document.body.appendChild(m);
        setTimeout(function () {
            var d = 0.5;
            m.style.transition = '-webkit-transform ' + d + 's ease-in, opacity ' + d + 's ease-in';
            m.style.opacity = '0';
            setTimeout(function () { document.body.removeChild(m) }, d * 1000);
        }, duration);
    }
    function addDownBtn(element, command) {
        let btnArtist = document.createElement('a')
        btnArtist.id = 'artist down'
        btnArtist.text = '下载'
        btnArtist.innerHTML = '<button class="button"><span>下载</span></button>'
        btnArtist.addEventListener('click', async function (e) {
            let resp = await fetchRemote({ path: 'addTask', data: JSON.stringify({ auth: token, task: command }), get: false })
            showToast(resp, 2000)
        });
        element.appendChild(btnArtist)
    }
    function loopChildToAddBtn(elements, prefix) {
        for (let index = 0; elements != null && index < Math.min(elements.length, 4); index++) {
            let element = elements[index];
            if (element.children.length == 1) {
                let name = element.children[0].text
                addDownBtn(element, prefix + '"' + name + '"')
            }
        }
    }

    let reg = new RegExp('\/(?<type>\\w+)\/(?<sex>(male|female))?:?(?<name>.+)-all')
    function parseTagFromUrl(url) {
        let groups = reg.exec(url)
        if (groups != null && groups.length) {
            let namedGroup = groups.groups
            var name = namedGroup['name']
            var type = namedGroup['type']
            if (namedGroup['sex'] != null) {
                type = namedGroup['sex']
            }
            if (name == 'loli') {
                name = 'lolicon'
            }
            return [type, name]
        }
        return []
    }

    function listTags(tags) {
        let enTags = []
        let transMap = new Map()
        for (const child of tags.children) {
            let a = child.children[0]
            let url = decodeURIComponent(a.getAttribute('href'))
            let [type, name] = parseTagFromUrl(url)
            if (type != null && name != null) {
                let map = new Map()
                map['name'] = name
                map['type'] = type
                if (excludes.find((l)=>`${l}`.indexOf(name) >= 0)) {
                    a.style = 'background: red;'
                }
                var list = transMap.get(url)
                if (list == null) {
                    list = []
                    transMap.set(url, list)
                }
                list.push(a)
                enTags.push(map)
            }
        }
        return [enTags, transMap]
    }

    async function translateTag(enTags, transMap) {
        if (remoteUrl == null || remoteUrl.length == 0) {
            return
        }
        let [type, name] = parseTagFromUrl(decodeURIComponent(window.location.href))
        if (type != null && name != null && !enTags.some((obj) => obj.type == type && obj.name == name)) {
            let map = new Map()
            map['name'] = name
            map['type'] = type
            enTags.push(map)
        }
        let data = JSON.stringify({ auth: token, tags: enTags })
        let respData = await fetchRemote({ path: 'translate', data: data, get: false })
        let resp = JSON.parse(respData)
        transMap.forEach(function (v, k) {
            for (const a of v) {
                let [type, name] = parseTagFromUrl(k)
                if (type != null && name != null) {
                    let v = resp.find((obj) => obj.type == type && obj.name == name)
                    if (v != null) {
                        a.innerText = `${takeShowText(v['translate'])}(${name})`
                        let intro = v['intro']
                        if (intro != null && intro.length || v.count != null) {
                            a.addEventListener('mouseover', () => {
                                let extension = document.querySelector('#extension')
                                extension.innerHTML = ''
                                extension.style.cssText = `top:${a.getBoundingClientRect().y + document.documentElement.scrollTop}px`
                                extension.classList.remove("hide")
                                if (intro != null && intro.length) {
                                    extension.appendChild(covertHtml(intro))
                                }
                                if (v.count != null) {
                                    let p = document.createElement('p')
                                    p.innerText = `已下载:(${v.count}),最后更新:${v.date}`
                                    extension.appendChild(p)
                                }
                                // extension.appendChild(covertHtml(v['links']))
                                a.addEventListener('mouseout', () => {
                                    extension.classList.add("hide")
                                });
                            });
                        }
                    }
                }
            }
        })
        if (type != null && name != null) {
            let v = resp.find((obj) => obj.type == type && obj.name == name)
            if (v != null) {
                let top = document.querySelector('.top-content')
                let info = document.createElement('div')
                info.style.cssText = "display: inline-block;width:100%;background-color: #777;opacity:0.75"
                document.querySelector('#artistname').innerText = `${name}(${v.count}) at ${v.date}`
                if (v['intro'] != null) {
                    info.appendChild(covertHtml(v['intro']))
                    info.appendChild(covertHtml(v['links']))
                }
                top.appendChild(info)
            }
        }
    }
    let urlReg = /!?\[(?<name>.*?)\]\(#*\s*\"?(?<url>\S+?)\"?\)/gm;
    let imgExtension = ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.avif', '.gif', '.bmp']
    function takeShowText(text) {
        var array
        var start = 0
        var title = ''
        while ((array = urlReg.exec(text)) != null) {
            title += text.slice(start, array.index)
            start = array.index + array[0].length
        }
        title += text.slice(start)
        return title
    }

    function covertHtml(text) {
        var array
        let result = document.createElement('div')
        result.style.cssText = "color:white;max-width:960px;overflow-x:hidden;overflow-y:hidden"
        var start = 0
        var title = ''
        while ((array = urlReg.exec(text)) != null) {
            let url = array.groups.url
            let name = array.groups.name
            if (imgExtension.some((ext) => url.endsWith(ext))) {
                let img = document.createElement('img')
                img.src = url
                img.style.cssText = "width:128px;max-height:256px;margin:8px"
                img.alt = name
                result.appendChild(img)
            } else {
                let img = document.createElement('a')
                img.style.cssText = "margin:8px"
                img.target = "_blank"
                img.href = url
                img.innerText = name
                result.appendChild(img)
            }
            title += text.slice(start, array.index).trim()
            start = array.index + array[0].length
        }
        title += text.slice(start).trim()
        if (title.length) {
            let p = document.createElement('p')
            p.innerText = title
            result.appendChild(p)
        }
        return result
    }

    function appendTags([enTags, transMap], [et, es]) {
        enTags.push(...et)
        es.forEach(function (v, k) {
            let old = transMap.get(k)
            if (old == null) {
                old = []
                transMap.set(k, old)
            }
            old.push(...v)
        })
        return [enTags, transMap]
    }

    function appendQueryTask(queryTask, ol) {
        ol.innerHTML = ""
        if (queryTask) {
            document.querySelector("#queryTaskLabel").innerText = `查询列表(${queryTask.length})`
            queryTask.forEach((task) => {
                let item = document.createElement('li')
                item.className = "item"
                let href = document.createElement('a')
                href.href = task.href
                href.target = "_blank"
                href.innerText = task.name
                item.appendChild(href)
                ol.appendChild(item)
            })
        }
    }

    function appendDwonTask(downTask, ol, labelName, showName) {
        ol.innerHTML = ""
        if (downTask) {
            document.querySelector(`#${labelName}`).innerText = `${showName}(${downTask.length})`
            downTask.forEach((task) => {
                let gallery = JSON.parse(task['gallery'])
                let item = document.createElement('li')
                item.className = "item"
                item.id=gallery.id
                let href = document.createElement('a')
                href.href = gallery.galleryurl
                href.target = "_blank"
                href.innerText = task.title
                if (task['speed'] != null) {
                    href.innerText = `${href.innerText}-(${task['current'] + 1}/${gallery.files.length})-${task['speed'].toFixed(2)}Kb/${(task['length'] / 1024).toFixed(2)}`
                }
                item.appendChild(href)
                ol.appendChild(item)
            })
        }
    }

    var socket = null

    async function showTask() {
        let remoteTask = document.createElement('div')
        remoteTask.className = "bottom-dialog"
        remoteTask.id = "taskBar"
        remoteTask.style.cssText = "min-width:768px;background-color: #666;max-height:720px;overflow: scroll; "
        remoteTask.innerHTML = `
        <div>
        <table class="table">
          <tbody>
            <caption>任务队列</caption>
            <tr>
              <td class="label" id="queryTaskLabel">查询列表</td>
              <td>
                <ul id="queryTask" class="tags"></ul>
              </td>
            </tr>
            <tr>
              <td class="label" id="pendingTaskLabel">等待列表</td>
              <td>
                <ul id="pendingTask" class="tags"></ul>
              </td>
            </tr>
            <tr>
            <td class="label" id="runningTaskLabel">下载列表</td>
            <td>
              <ul id="runningTask" class="tags"></ul>
            </td>
            </tr>
          </tbody>
        </table>
      </div>
        `
        document.body.appendChild(remoteTask)
        await listTaskContent()
    }

    async function listTaskContent() {
        socket = new WebSocket('wss://baijunty.com/listTask');
        socket.addEventListener("open", function (event) {
            socket.send(JSON.stringify({ auth: token,'type':'list'}));
        });
        socket.addEventListener("message", function (event) {
            var respData = event.data;
            let resp = JSON.parse(respData)
            switch(resp['type']){
                case 'list':{
                    appendQueryTask(resp['queryTask'], document.getElementById('queryTask'))
                    appendDwonTask(resp['pendingTask'], document.getElementById('pendingTask'), 'pendingTaskLabel', '等待列表')
                    appendDwonTask(resp['runningTask'], document.getElementById('runningTask'), 'runningTaskLabel', '下载列表')
                    break;
                }
                case 'add':{
                    let target=resp['target'];
                    var parent=document.getElementById('pendingTask')
                    if (target =='running'){
                        parent=document.getElementById('runningTask')
                    }
                    let gallery = JSON.parse(resp['gallery'])
                    let item = document.createElement('li')
                    item.className = "item"
                    item.id=gallery.id
                    let href = document.createElement('a')
                    href.href = gallery.galleryurl
                    href.target = "_blank"
                    let name = document.createElement('h')
                    name.innerText = `${gallery.title}`
                    href.appendChild(name)
                    item.appendChild(href)
                    parent.appendChild(item)
                }
                case 'remove':{
                    let item=document.getElementById(resp['id'])
                    if (item!=null){
                        item.remove()
                    }
                    break;
                }
                case 'update':{
                    let task=resp
                    let item=document.getElementById(resp['id'])
                    let href= item.querySelector('a')
                    if(href!=null){
                        var speed =  href.querySelector('p')
                        if(speed!=null){
                            speed.remove()
                        }
                        speed=document.createElement('p')
                        speed.innerText = `(${task['current'] + 1}/${task.length})-${task['speed'].toFixed(2)}Kb/${(task['length'] / 1024).toFixed(2)}`
                        href.appendChild(speed)
                    }
                }
            }
        });
    }

    async function listThumbImages() {
        let match = RegExp('(?<id>\\d+).html').exec(window.document.location.href)
        if (match != null && match.length) {
            let id = parseInt(match.groups['id'])
            let respData = await fetchRemote({ path: 'checkId', data: JSON.stringify({ auth: token, id: id }), get: false })
            let resp = JSON.parse(respData)
            console.log(resp)
            let title = document.querySelector('#gallery-brand')
            if (title != null) {
                let btnArtist = document.createElement('a')
                btnArtist.style.cssText = "color: red;font-size: 18px;font-style: normal;text-shadow: none;"
                if (resp.value.length) {
                    btnArtist.innerHTML = `<a href="/doujinshi/${resp.value[0]}.html" target="_blank"><span> ${resp.value[0]} </span></a>`
                } else {
                    btnArtist.innerText = "无"
                }
                title.appendChild(btnArtist)
            }
        }
    }

    let start = function () {
        let [enTags, transMap] = [[], new Map()]
        if (manga != null && manga.length) {
            manga[0].childNodes.forEach(element => {
                let [tags, trans] = Array.from(element.getElementsByTagName('ul')).reduce(function (list, uls) {
                    list.push(uls)
                    return list
                }, []).reduce(function ([tags, trans], ul) {
                    appendTags([tags, trans], listTags(ul))
                    return [tags, trans]
                }, [[], new Map()])
                appendTags([enTags, transMap], [tags, trans])
                let artistList = element.getElementsByClassName('artist-list')[0];
                if (artistList != null) {
                    Array.from(artistList.children).forEach(e => {
                        loopChildToAddBtn(e.children, '-a ')
                    });
                }
            });
        }
        let title = document.getElementById('gallery-brand')
        if (title != null) {
            let element = title.children[0]
            let idRegExp = RegExp('\\d+')
            let id = idRegExp.exec(element.getAttribute('href'))[0]
            addDownBtn(title, id)
        }
        let groups = document.getElementById('groups')
        if (groups != null && groups.children.length) {
            let elements = groups.children[0]
            appendTags([enTags, transMap], listTags(elements))
            loopChildToAddBtn(elements.children, '-g ')
        }
        let artistList = document.getElementById('artists')
        if (artistList != null && artistList.children.length) {
            let elements = artistList.children[0]
            appendTags([enTags, transMap], listTags(elements))
            loopChildToAddBtn(elements.children, '-a ')
        }
        let series = document.getElementById('series')
        if (series != null && series.children.length) {
            series.childNodes.forEach((e) => appendTags([enTags, transMap], listTags(e)))
        }
        let characters = document.getElementById('characters')
        if (characters != null) {
            appendTags([enTags, transMap], listTags(characters))
        }
        let tags = document.getElementById('tags')
        if (tags != null) {
            appendTags([enTags, transMap], listTags(tags))
        }
        translateTag(enTags, transMap)
        listThumbImages()
    }
    function showDialog() {
        document.getElementById('dialog-background').open = true
        let input = document.getElementById('remote-address')
        input.value = remoteUrl
        let tokenInput = document.getElementById('remote-token')
        tokenInput.value = token
        let tags = document.getElementById('remote-tags')
        tags.value = saveExculdes
        document.getElementById('remote-confirm').addEventListener('click', async function (e) {
            let resp = await fetchRemote({ path: 'test', baseHttp: input.value }).then(function (resp) {
                return JSON.parse(resp)
            })
            if (resp.success) {
                GM_setValue('hitomi_la_remote_url', input.value)
                GM_setValue('hitomi_la_remote_token', tokenInput.value)
                GM_setValue('hitomi_la_remote_excludes_tags', tags.value)
                showToast('地址已设置为' + input.value, 2000)
                remoteUrl = input.value
                token = tokenInput.value
            } else {
                showToast('地址错误', 2000)
            }
        })
    }
    let observer = new MutationObserver(start)
    observer.observe(manga[0], { childList: true })
    let nav = document.getElementsByTagName('nav')[0]
    if (nav != null) {
        let ul = nav.children[0]
        let dialogHtml = `<dialog closeOnclick="true" class="dialog-box" id="dialog-background">
         <form method="dialog" class="dialog">
          <div style="display: flex; justify-content: center">
            <h4>远程地址设置</h4>
          </div>
          <div style="display: flex; justify-content: space-between">
            <label for="remote-address" class="label">地址：</label>
            <input type="text" id="remote-address" style="width: 80%;margin-left:10px" />
          </div>
          <div style="display: flex; justify-content: space-between;margin-top:10px">
            <label for="remote-token" class="label">token：</label>
            <input type="text" id="remote-token" style="width: 80%;margin-left:10px" />
          </div>
          <div style="display: flex; justify-content: space-between;margin-top:10px">
            <label for="remote-tags" class="label">过滤标签：</label>
            <input type="text" id="remote-tags" style="width: 80%;margin-left:10px" />
          </div>
          <div style="display: flex; justify-content: center; margin-top:10px">
             <button class="button" value="cancel">取消</button>
            <button class="button" id="remote-confirm">确定</button>
          </div>
        </form>
      </dialog>
    `
        let dialog = document.createElement('div')
        dialog.innerHTML = dialogHtml
        document.body.appendChild(dialog);
        let setting = document.createElement('li')
        setting.innerHTML = '<button style="background-color: transparent;border: none;margin-top:5px;align:center"><img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABkAAAAZCAYAAADE6YVjAAAACXBIWXMAAAsTAAALEwEAmpwYAAAB9ElEQVR4nM2Wy0rbURDGf5CV9Ral2oVU+wQGn0FRQYwXClXbl1AXIr6Agoh14X2haJONoEhpNfVBDNWFuvayjBuVgS9ycvhfNKL4QcjJmZlvzpwzl8A7w3fgXp87oP81nPwExrSeAqZfQlYBrAMD3n4O6NY6Dfz25BbZmuxjHRjZLnACrAB1wBBwBXyW3hfgEvgK1ABLwCmwJ/tIR8vAPpAAqoFN4BbIAF2ebg+wI/mWnCVkb05DYURnQNLZs0ii8NHTNfvOGBsWgF+Uhyww/xRFi6IQEMEHYASYAIaBSk/+SXZVT3HyA9j29lqBPHAAzOn7Akh5epYwg1GFZtd0BNwA7V4EeZ3ehUV17GVSWln4T3VlOo+4V6HZgzUFkNnJg5BTertoVj2Ni/cRJT88TAKzIbJZycNQwnsn5V6dxIVd02EISVAkLeKZFG9JS5gB/upOOxxZpR55JOAdz/VmRfSpE/wRX/9zsiulR84pu3Jy0Obp7UVll4s6tQq36lEWDalOvnkRGBpVJ9ZeYrEKbFAetoDFOCVr7//VHIuoj7FpcNY16t6RA21dVZvQdWV0ddmILlyQPCm7XfHEzpN9dVOr2lql8bVTqC3OPKmW3pnsYudJ0dFSQLs+cqLpVZq66JRdrIMoLACjWr94xofhTf6tlI0Hwy9xXk523BQAAAAASUVORK5CYII="></button>'
        setting.addEventListener('click', function (e) {
            showDialog()
            e.preventDefault()
        })
        ul.appendChild(setting)
    }
    let top = document.querySelector('.top-content')
    top.childNodes.forEach(element => element.remove())
    let extension = document.createElement('div');
    extension.id = "extension"
    extension.className = "right-frame"
    extension.classList.add("right-frame", "hide")
    document.body.appendChild(extension);
    let bottomMenu = document.createElement('div')
    bottomMenu.style.cssText = `position: fixed;bottom: 20px;left: 80%;`
    bottomMenu.innerHTML = `
        <div style="display:grid">
        <button id="scrollTop">
         <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAAsTAAALEwEAmpwYAAABhElEQVR4nN2VvU4CURCFv0CgEX0ACx9A6Kws/eklqNBZGo0Eo43PoPgC9AbfxMpKMGLAwkJ6g4miBeYm5yYT3GXvWnKSSXZn5s7Mnpm5C/OOPFAD2kAP+JD0pKvK51/YBV6ASYIMgEqawFng2gR4AE6BIrAgKUrXMX5NIBOSwAf/Ao4TDrliToCxzlyF0OKDb6T46k2TpBznlDecH5EedZ3txzW+ZjiPoiUPtCT5GLq6irEfleBWxkaEbRm4Mw29B1Yi/M5kv4lK8Czj6pR+HRhGjOdQNouSbG5P/mAkY8HoDk3zxno/AD6l+wEujP+i9KNZCZyTx0TyNlXtGvBq7B5Len8PpWgi7l0PZvUliKK2jG5DPVoJd42frKAmV2XsaOTSIgs8KsZeXDUDObj1T4uGWbRcnFPFTMxWiuDbwLfO7iQ5N02SegJdWVXug1+GVJPRrehHsKvmlbQjBT2fG8598KDr2qMsPpN+OP0QWuKQ08Xlxu5Jy+jEPTudm5bYhs4HfgGN1o3ytrKE/gAAAABJRU5ErkJggg=="/>
          <p style="text-align: center;margin:0px;">顶部</p>
          </button>
           <button id="taskIcon" style="margin:8px 0px 0px 0px">
          <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAsklEQVR4nO2TwQ3CMAxF3xKJYBQYAnWN9gC70gMrsIV7CVJUFZKmdlAhT/Itrt93UmiUcwOeoa5UpgNkVhfNAZJZJ+C84ry6wAszgZjcj2zp3YeAFKz7NwS20ATkr67AA/23BDwwht6htoAD7qHvARwsBPqQ8lPyceGMisDwZkBquJqAm634mFi7usBS2lRyk0footSp5CYCsUTOcLPf0CfWbi6whiYgpVcgyrUfgQa1mABvie4DBGMStQAAAABJRU5ErkJggg=="
          />
          <p style="text-align: center;margin:0px;">任务</p>
        </button>

           <button id="scrollBottom" style="margin:8px 0px 0px 0px">
         <img src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAAsTAAALEwEAmpwYAAABiUlEQVR4nN2VTU4CQRCFv0AgMeLShRxBuICu/NtLUOEGRiPByC0UL8BWDR7DlR5AMGLQLQuX6ELcjOnkddIZujMzLnlJJ9NV1a+K11UNLDqKQBPoAyPgW2skW0Mx/8IB8AFECesdqGchzgPXDsEzcA5UgGWtimwDJ64L5NIksOQ/wGnCIVPMGTDTmas0sljy7Qy/esdJUgsFFR3NT8iOls6OQxffdDRPpaVHrqE4jvDgXs62Y7sBlgjDVNpz9hfiuPMFv8m57tgi4Akoe+LL8pkYi6r2Zk7m8CVnKZYgAj6BLce+CUwcv8WK9oZrDlM5TZDFsdMdM+19tniCaVqJDDZi1do1kY+0EvXlNBMaxyrw4JA/AmueuI78t74EDTkHarlQx/QCfW7OvIjj0JegqIcr0vhnRdsZtEIoqO5c3m4G8j3gV2f3k4K7TpJWQC6LvCq35JdpqsnpVbQXOtSEVjUjJX13HM0teaYnpiY9k/5wxmlkCaGgh8u8La+aULPMt7GZbgle6GLgD1GcjfQfQa4oAAAAAElFTkSuQmCC"/>
          <p style="text-align: center;margin:0px;">底部</p>
        </button>
        </div>
      `
    document.body.appendChild(bottomMenu)
    document.querySelector("#taskIcon").addEventListener('click', async function (e) {
        let taskBar = document.querySelector("#taskBar")
        if (taskBar == null) {
            showTask()
        } else {
            taskBar.classList.add('remove')
            setTimeout(() => document.body.removeChild(taskBar), 500)
            if (socket != null) {
                socket.close()
            }
        }
        e.preventDefault()
    })
    document.querySelector("#scrollTop").addEventListener('click', async function (e) {
        window.scrollTo({ top: 0, left: 0, behavior: "smooth" });
        e.preventDefault()
    })
    document.querySelector("#scrollBottom").addEventListener('click', async function (e) {
        window.scrollTo({ top: document.body.scrollHeight, behavior: "smooth" });
        e.preventDefault()
    })
})();