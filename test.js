
const urlReg = /!?\[(?<name>.*?)\]\(#?\s*\"?(?<url>\S+?)\"?\)/gm;
let str=`
来自游戏[碧蓝幻想（Granblue Fantasy）](https://zh.moegirl.org.cn/碧蓝幻想)。\n\n守护东北东方位、十二神将中的一位。不，两位。其真实身份是自桃中诞生的非凡双子。以风水掌控运势，决定场面吉凶。只要身边有了这对姐妹，无论走向何方，前途都会大吉大利吧。
`
function compileText(text) {
    var array
    let result=[]
    var start=0
    while ((array = urlReg.exec(text)) != null) {
        let obj={}
        obj[array.groups.name]=array.groups.url
        result.push(text.slice(start,array.index))
        result.push(obj)
        start=array.index+array[0].length
    }
    result.push(text.slice(start))
    return result
}
let r=compileText(str)
r.forEach(e=>console.log(e))