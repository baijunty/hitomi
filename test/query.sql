select g.id,t.name,g.path,g.title from Gallery g LEFT JOIN Tags t 
on (g.author=t.translate and t.type='artist') WHERE t.name  = Lower('Akasa Tanu')
SELECT count(1) FROM Gallery g where g.length!=0
select * from Tags where 
SELECT * from Tasks WHERE completed=0
SELECT * FROM Gallery g where id=1793948
select * from GalleryFile where gid=1793948 group by gid



select g.id,g.path,gf.fileHash,gf.name,g.author from (select g.* from Gallery g,json_each(g.author) ja where (json_valid(g.author)=1 and ja.value in ('hanahanamaki','sousouman') )
union all
select g.* from Gallery g,json_each(g.groupes) jg where (json_valid(g.groupes)=1 and jg.value = 'twinbox' )) as g LEFT JOIN GalleryFile gf  on gf.gid =g.id where gf.hash is not null group by g.id order by gf.name 