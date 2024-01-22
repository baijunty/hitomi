select g.id,t.name,g.path,g.title from Gallery g LEFT JOIN Tags t 
on (g.author=t.translate and t.type='artist') WHERE t.name  = Lower('Akasa Tanu')
SELECT * FROM Gallery where id=2312852
select * from Tags where translate = '乱伦'
SELECT * from Tasks WHERE completed=0
select * from Tags where type='type' limit 20