select g.id,t.name,g.path,g.title from Gallery g LEFT JOIN Tags t 
on (g.author=t.translate and t.type='artist') WHERE t.name  = Lower('Akasa Tanu')
SELECT * FROM Gallery g where id=1077557
SELECT * from Tasks WHERE completed=0

select count(distinct(gid)) from GalleryFile where gid=1435461 order by name

select g.* from Gallery g where id=2043893
select * from GalleryFile where gid=1435461 order by name
select g.* from Gallery g,json_each(g.artist) ja where (json_valid(g.artist)=1 and ja.value = 'more' )
LEFT JOIN GalleryFile gf  on gf.gid =g.id where gf.hash is not null group by g.id order by gf.name

select g.id,g.path,gf.fileHash,gf.name,g.author from (select g.* from Gallery g,json_each(g.artist) ja where (json_valid(g.artist)=1 and ja.value in ('tachibana omina') )
union all
select g.* from Gallery g,json_each(g.groupes) jg where (json_valid(g.groupes)=1 and jg.value = '' )) as g LEFT JOIN GalleryFile gf  on gf.gid =g.id where gf.hash is not null group by g.id order by gf.name 