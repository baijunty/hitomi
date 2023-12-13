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
(function () {
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
    let manga = document.getElementsByClassName('gallery-content');
    var remoteUrl = GM_getValue('hitomi_la_remote_url', '')
    var token = GM_getValue('hitomi_la_remote_token', '')
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
        btnArtist.id = 'artist down'
        btnArtist.text = '下载'
        btnArtist.innerHTML = '<button class="button"><span>下载</span></button>'
        btnArtist.addEventListener('click', function (e) {
            try {
                GM_xmlhttpRequest({
                    method: 'POST',
                    responseType: 'json',
                    timeout: 30000, // 3秒超时
                    url: remoteUrl + 'addTask',
                    data: JSON.stringify({ auth: token, task: command }),
                    onload: function (res) {
                        if (res.status == 200) {
                            showToast(res.responseText, 2000)
                        } else {
                            alert('http error ' + res.status);
                        }
                    },
                });
            } catch (error) {
                alert('http invoke error' + error);
            }
        });
        element.appendChild(btnArtist)
    }
    function loopChildToAddBtn(elements, prefix) {
        for (let index = 0; elements != null && index < Math.min(elements.length, 4); index++) {
            let element = elements[index];
            let name = element.children[0].text
            addDownBtn(element, prefix + '"' + name + '"')
        }
    }
    let reg=new RegExp('\/(?<type>\\w+)\/(?<sex>(male|female))?:?(?<name>.+)-all')
    function listTags(tags){
        let enTags=[]
        let transMap=new Map()
        for (const child of tags.children) {
            let a=child.children[0]
            let groups= reg.exec(decodeURIComponent(a.getAttribute('href')))
            if(groups!=null&&groups.length){
                let namedGroup=groups.groups
                let map=new Map()
                let name=namedGroup['name']
                if(namedGroup['sex']!=null){
                    map['type']=namedGroup['sex']
                } else {
                    map['type']=namedGroup['type']
                }
                map['name']=name
                var list=transMap.get(name)
                if(list==null){
                    list = []
                    transMap.set(name,list)
                }
                list.push(a)
                enTags.push(map)
            }
        }
        return [enTags,transMap]
    }

    function translateTag(enTags,transMap) {
        if(remoteUrl==null||remoteUrl.length==0){
            return
        }
        let data=JSON.stringify({ auth: token, tags: enTags})
        GM_xmlhttpRequest({
            method: "POST", responseType: 'json',
            timeout: 300000, // 3秒超时
            data: data,
            url: remoteUrl + 'translate',
            onload: function (res) {
                if (res.status == 200) {
                    let resp = JSON.parse(res.responseText)
                    if (resp.success) {
                        transMap.forEach(function(v,k){
                            for (const a of v) {
                                a.innerText=`${resp[k]}(${k})`
                            }
                        })
                    }
                }
            }
        })
    }

    function appendTags([enTags,transMap],[et,es]){
        enTags.push(...et)
        es.forEach(function(v,k){
            let old=transMap.get(k)
            if(old==null){
                old=[]
                transMap.set(k,old)
            }
            old.push(...v)
        })
        return [enTags,transMap]
    }

    let start = function () {
        let [enTags,transMap]=[[],new Map()]
        if (manga != null && manga.length) {
            manga[0].childNodes.forEach(element => {
                let artistList = element.getElementsByClassName('artist-list')[0];
                if (artistList != null) {
                    Array.from(artistList.children).forEach(e => {
                        let artist = e.children
                        appendTags([enTags,transMap],listTags(e))
                        loopChildToAddBtn(artist, '-a ')
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
            appendTags([enTags,transMap],listTags(elements))
            loopChildToAddBtn(elements.children, '-g ')
        }
        let artistList = document.getElementById('artists')
        if (artistList != null && artistList.children.length) {
            let elements = artistList.children[0]
            appendTags([enTags,transMap],listTags(elements))
            loopChildToAddBtn(elements.children, '-a ')
        }
        let series = document.getElementById('series')
        if (series != null&&series.length) {
            let elements = series.children[0]
            appendTags([enTags,transMap],listTags(elements))
        }
        let characters = document.getElementById('characters')
        if (characters != null&&characters.length) {
            appendTags([enTags,transMap],listTags(characters))
        }
        let tags = document.getElementById('tags')
        if (tags != null) {
            appendTags([enTags,transMap],listTags(tags))
        }
        let tagPanels = document.getElementsByClassName('dj-desc')
        if (tagPanels != null && tagPanels.length) {
            Array.from(tagPanels).map((panel)=>panel.getElementsByTagName('ul')).reduce(function(list,uls){
                list.push(...uls)
                return list
            },[]).forEach(function (e){
                appendTags([enTags,transMap],listTags(e))
            })
        }
        translateTag(enTags,transMap)
    }
    function showDialog() {
        document.getElementById('dialog-background').open=true
        let input = document.getElementById('remote-address')
        input.value = remoteUrl
        let tokenInput = document.getElementById('remote-token')
        tokenInput.value = token
        document.getElementById('remote-confirm').addEventListener('click', function (e) {
            GM_xmlhttpRequest({
                method: 'GET', url: input.value, timeout: 3000, onload: function (res) {
                    if (res.status == 200 && res.responseText == 'ok') {
                        GM_setValue('hitomi_la_remote_url', input.value)
                        GM_setValue('hitomi_la_remote_token', tokenInput.value)
                        showToast('地址已设置为' + input.value, 2000)
                        remoteUrl = input.value
                        token = tokenInput.value
                    } else {
                        showToast('地址错误', 2000)
                    }
                    document.getElementById('dialog-background').open=false
                }
            })
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