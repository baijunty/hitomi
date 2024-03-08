
SELECT * FROM Gallery g,json_each(g.artist) ja  where (json_valid(g.artist)=1 and ja.value = 'michiking') 
SELECT * from Tasks WHERE completed=0
SELECT * FROM Tags WHERE name='kotori minami'
select count(1) from Gallery g 
select count(distinct(gid)) from GalleryFile where gid=1435461 order by name
select * from Gallery g  where id=719417
select distinct(ja.value) from Gallery g,json_each(g.artist) ja where json_valid(g.artist)=1 group by ja.value  limit 20
select * from GalleryFile where gid=1237376   order by name
select gf.gid,gf.fileHash,gf.name,g.path,g.length from Gallery g,json_each(g.artist) ja left join GalleryFile gf on g.id=gf.gid 
where (json_valid(g.artist)=1 and ja.value = 'yahiro pochi' ) order by gf.gid,gf.name

SELECT gf.gid  from (SELECT DISTINCT(gid) from GalleryFile)  gf WHERE  not EXISTS (SELECT 1 from Gallery g WHERE g.id=gf.gid)
select g.id from  Gallery g,json_each(g.artist) ja left join GalleryFile gf on g.id=gf.gid where json_valid(g.artist)=1 and ja.value = 'fuuga' and gf.gid is null
