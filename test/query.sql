
SELECT g.* FROM Gallery g,json_each(g.artist) ja  where (json_valid(g.artist)=1 and ja.value = 'tel') 
SELECT * from Tasks WHERE completed=0
select * from Tags WHERE name LIKE 'loli%'
select * from GalleryFile where gid=2240431 order by name
select count(distinct(gid)) from GalleryFile where gid=1435461 order by name
select * from Gallery g where g.id=776601
select distinct(ja.value) from Gallery g,json_each(g.artist) ja where json_valid(g.artist)=1 group by ja.value  limit 20
select * from GalleryFile where gid=1261783  order by name
select gf.gid,gf.fileHash,gf.name,g.path,g.length from Gallery g,json_each(g.artist) ja left join GalleryFile gf on g.id=gf.gid 
where (json_valid(g.artist)=1 and ja.value = 'yahiro pochi' ) order by gf.gid,gf.name

select gf.gid,gf.fileHash,gf.name,g.path,g.length from Gallery g,json_each(g.artist) ja left join GalleryFile gf on g.id=gf.gid where 
(json_valid(g.artist)=1 and ja.value = 'anma' and gf.gid  !=NULL and g.id=1082011) order by gf.gid,gf.name

select g.id from  Gallery g,json_each(g.artist) ja left join GalleryFile gf on g.id=gf.gid where json_valid(g.artist)=1 and ja.value = 'fuuga' and gf.gid is null