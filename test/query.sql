select g.id,t.name,g.path,g.title from Gallery g LEFT JOIN Tags t 
on (g.author=t.translate and t.type='artist') WHERE t.name  = Lower('yuzuha')
SELECT * FROM Gallery where tags like '%162747%'
select * from Tags where  name='guro'
SELECT * from Tasks WHERE completed=0