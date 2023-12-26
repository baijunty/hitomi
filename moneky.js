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
        display: inline-block;
        font-size: 12px;
        margin: 4px 2px;
        cursor: pointer;
        margin-left: 10px;
      }
    .label {
      width:120px;
      background-color:green;
      color:white;
      text-align:right
    }
      `)
    var remoteUrl = GM_getValue('hitomi_la_remote_url', '')
    async function fetchRemote({path, data = null, get = true,baseHttp=remoteUrl}) {
        let url=baseHttp + path
        return new Promise(function (resolve) {
            GM_xmlhttpRequest({
                method: get ? 'GET' : 'POST',
                responseType: 'json',
                timeout: 30000, // 3秒超时
                url:url,
                data: data,
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
    var saveExculdes=GM_getValue('hitomi_la_remote_excludes_tags', '')
    let excludes
    if(saveExculdes.length==0){
        saveExculdes=await fetchRemote({path:'excludes',data:JSON.stringify({auth: token}),get:false})
        excludes=JSON.parse(saveExculdes)
        GM_setValue('hitomi_la_remote_excludes_tags', saveExculdes)
    } else {
        excludes=JSON.parse(saveExculdes)
    }
    function showToast(msg, duration) {
        duration = isNaN(duration) ? 3000 : duration;
        var m = document.createElement('div');
        m.innerHTML = msg;
        m.style.cssText = "position: fixed;bottom: 20px;left: 50%;transform: translateX(-50%);background-color: #333;color: #fff; padding: 10px 20px;border-radius: 5px;opacity: 1;transition: opacity 0.3s ease-in-out;";
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
        btnArtist.text = '下载'
        btnArtist.innerHTML = '<button class="button"><span>下载</span></button>'
        btnArtist.addEventListener('click', async function (e) {
            let resp = await fetchRemote({path:'addTask', data:JSON.stringify({ auth:token, task: command }), get:false})
            showToast(resp, 2000)
        });
        element.appendChild(btnArtist)
    }
    function loopChildToAddBtn(elements, prefix) {
        for (let index = 0; elements != null && index < Math.min(elements.length, 4); index++) {
            let element = elements[index];
            if(element.children.length==1){
                let name = element.children[0].text
                addDownBtn(element, prefix + '"' + name + '"')
            }
        }
    }
    let reg = new RegExp('\/(?<type>\\w+)\/(?<sex>(male|female))?:?(?<name>.+)-all')
    function listTags(tags) {
        let enTags = []
        let transMap = new Map()
        for (const child of tags.children) {
            let a = child.children[0]
            let groups = reg.exec(decodeURIComponent(a.getAttribute('href')))
            if (groups != null && groups.length) {
                let namedGroup = groups.groups
                let map = new Map()
                let name = namedGroup['name']
                if (namedGroup['sex'] != null) {
                    map['type'] = namedGroup['sex']
                } else {
                    map['type'] = namedGroup['type']
                }
                map['name'] = name
                var list = transMap.get(name)
                if (list == null) {
                    list = []
                    transMap.set(name, list)
                }
                if(excludes.indexOf(name)>=0){
                    a.style='background: red;'
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
        let data = JSON.stringify({ auth: token, tags: enTags })
        let respData = await fetchRemote({path:'translate', data:data,get:false})
        let resp=JSON.parse(respData)
        transMap.forEach(function (v, k) {
            if (resp[k].toLowerCase() != k.toLowerCase()) {
                for (const a of v) {
                    a.innerText = `${resp[k]}(${k})`
                }
            }
        })
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

    let start = function () {
        let [enTags, transMap] = [[], new Map()]
        if (manga != null && manga.length) {
            manga[0].childNodes.forEach(element => {
                let [tags,trans]= Array.from(element.getElementsByTagName('ul')).reduce(function (list, uls) {
                    list.push(uls)
                    return list
                }, []).reduce(function ([tags,trans], ul) {
                    appendTags([tags,trans],listTags(ul))
                    return [tags,trans]
                }, [[],new Map()])
                appendTags([enTags,transMap],[tags,trans])
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
        if (series != null&& series.children.length) {
            series.childNodes.forEach((e)=> appendTags([enTags, transMap], listTags(e)))
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
            let resp = await fetchRemote({path:'',baseHttp:input.value})
            if (resp == 'ok') {
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
})();