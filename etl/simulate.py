"""Inserta 24 horas sintéticas, separadas del histórico, para series y alerta."""
import os,sys,psycopg
db=os.getenv('DATABASE_URL','postgresql://bi_user:secret@localhost:5432/vinilos_bi'); bad='--trigger' in sys.argv
with psycopg.connect(db) as c, c.cursor() as q:
 for i in range(1,5):
  q.execute('SELECT machine_key FROM dw.dim_machine WHERE machine_code=%s',(f'Vinilos_{i}',)); k=q.fetchone()[0]
  for offset in range(23,-1,-1):
   down=(18 if i==1 else 12) if offset==0 and bad else 12 if offset==0 else 4+(offset%4)
   q.execute("INSERT INTO dw.fact_live_hour(hour_start,machine_key,planned_minutes,run_minutes,downtime_minutes,produced_cases,source_mode) VALUES(date_trunc('hour',now())-(%s*interval '1 hour'),%s,60,%s,%s,%s,'simulation') ON CONFLICT(hour_start,machine_key) DO UPDATE SET run_minutes=excluded.run_minutes,downtime_minutes=excluded.downtime_minutes,produced_cases=excluded.produced_cases,source_mode='simulation'",(offset,k,60-down,down,120))
print('Serie horaria simulada: 24 horas x 4 líneas;', 'umbral excedido en Vinilos_1' if bad else 'escenario base')
