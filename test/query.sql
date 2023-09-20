select g.id,t.name,g.path,g.title from Gallery g LEFT JOIN Tags t 
on (g.author=t.translate and t.type='artist') WHERE t.name  = Lower('yuzuha')
SELECT * FROM Gallery WHERE id=1522590
select * from Tags where  name='yuzuha'
SELECT * from Tasks WHERE completed=0