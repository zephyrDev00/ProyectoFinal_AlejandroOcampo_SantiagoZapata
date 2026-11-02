"""Reproducible xlsm -> PostgreSQL dimensional load. Names of staff are never loaded."""
import os, re, json, datetime as dt, warnings
from decimal import Decimal
import openpyxl, psycopg
warnings.filterwarnings('ignore', category=UserWarning, module='openpyxl')
SOURCE=os.getenv('SOURCE_FILE','/source/SEGUIMIENTO TEMPERAS Y VINILOS Actividad.xlsm')
DB=os.getenv('DATABASE_URL','postgresql://bi_user:secret@localhost:5432/vinilos_bi')
MONTHS={1:'enero',2:'febrero',3:'marzo',4:'abril',5:'mayo',6:'junio',7:'julio',8:'agosto',9:'septiembre',10:'octubre',11:'noviembre',12:'diciembre'}
# The operational procedure P-MTO-22 describes these parent categories; unmapped stays visible.
STOP_LABELS={1:'Falla electromecánica/control',2:'Espera soporte mantenimiento',3:'Novedad sistemas de potencia',4:'Mantenimiento preventivo',5:'Ajuste operativo',6:'Limpieza por derrame',7:'Alistamiento/cambio referencia',8:'Capacitación/reunión',9:'Falta de operario',10:'Paro por ventaja/evacuación',11:'Reproceso',12:'Materia prima defectuosa',13:'Aval laboratorio microbiología',14:'Falta de materia prima',15:'Cambio de insumos',16:'Alimentación/aseo zona y máquina',17:'Pausa activa'}
# Source sheet columns, explicitly positional to avoid drift in wrapped Excel headers.
SLOTS=[(15,16,17),(18,None,19),(20,21,22),(23,None,24),(25,26,27)]+[(30+2*i,None,31+2*i) for i in range(13)] # 0-based

def n(v):
    if v is None or v=='': return None
    try: return Decimal(str(v))
    except Exception: return None

def token(v): return str(v).strip() if v not in (None,'') else ''
def dim_stop_key(code, sub):
    c=token(code); s=token(sub)
    if s: return 'sub:'+s
    return 'raw:'+c if c else 'unclassified'
def parent(code, sub):
    s=token(sub); c=token(code)
    m=re.match(r'\s*(\d{1,2})(?:[.\-]|\s)',s)
    if m:
        i=int(m.group(1)); return f'{i:02d}',STOP_LABELS.get(i),s
    # A raw 1..17 may be a category; larger values are retained as unmapped source tokens.
    if c.isdigit() and 1<=int(c)<=17: return f'{int(c):02d}',STOP_LABELS.get(int(c)),None
    return None,None,None

def main():
    if not os.path.isfile(SOURCE): raise SystemExit(f'No existe la fuente: {SOURCE}. Copie el .xlsm a data/; nunca se versiona.')
    wb=openpyxl.load_workbook(SOURCE,read_only=True,data_only=True,keep_vba=True)
    ws=wb['Base De Datos']; it=ws.iter_rows(min_row=9,values_only=True); hdr=next(it)
    cols={str(v).replace('\n',' ').strip():i for i,v in enumerate(hdr) if v}
    records=[]; invalid=[]; stops={}; qc={'blank_rows':0,'duplicate_content':0,'invalid_date':0,'unknown_machine':0,'negative_measure':0,'missing_shift':0,'missing_reference':0,'downtime_reconciliation_abs_gt_0_02h':0,'legacy_unmapped_stop_rows':0}
    src_count=0; seen_contents=set()
    for excel_row,row in enumerate(it,10):
        src_count+=1
        if not any(v is not None for v in row): qc['blank_rows']+=1; continue
        content=tuple(row)
        if content in seen_contents: qc['duplicate_content']+=1
        else: seen_contents.add(content)
        date=row[0] if len(row)>0 else None; machine=token(row[3] if len(row)>3 else None)
        if not isinstance(date,(dt.datetime,dt.date)): qc['invalid_date']+=1; invalid.append((excel_row,'fecha_invalida')); continue
        if machine not in {'Vinilos_1','Vinilos_2','Vinilos_3','Vinilos_4'}: qc['unknown_machine']+=1; invalid.append((excel_row,'maquina_desconocida')); continue
        d=date.date() if isinstance(date,dt.datetime) else date
        # Keep valid repeats: identical day/shift/product runs can be distinct source records.
        shift=token(row[11]) or 'SIN TURNO'; ref=token(row[5]) or 'SIN REFERENCIA'
        if not token(row[11]): qc['missing_shift']+=1
        if not token(row[5]): qc['missing_reference']+=1
        vals=[n(row[i]) if i<len(row) else None for i in (9,10,12,56)]
        cases,op_hours,nonwork,reported=vals
        if any(x is not None and x<0 for x in vals):
            qc['negative_measure']+=1; invalid.append((excel_row,'medida_negativa')); continue
        stop_items=[]; detail_total=Decimal('0')
        for slot,(ci,si,hi) in enumerate(SLOTS,1):
            c=row[ci] if ci<len(row) else None; sub=row[si] if si is not None and si<len(row) else None; dur=n(row[hi] if hi<len(row) else None)
            if dur is None or dur<=0: continue
            detail_total+=dur
            label=token(sub) or token(c) or 'Sin clasificación en fuente'
            tokenkey=dim_stop_key(c,sub); code,code_label,subcode=parent(c,sub)
            stop_name=code_label or token(sub) or (f'Sin clasificar ({token(c)})' if token(c) else 'Sin causa identificada')
            stops[tokenkey]=(tokenkey,code,stop_name,subcode,token(sub) or None,token(row[28]) or None,token(row[29]) or None,'subcodigo' if sub else ('codigo' if code else 'sin_clasificar'),bool(code or sub))
            stop_items.append((tokenkey,slot,dur,'horas_detalle',label))
        if not stop_items and reported and reported>0:
            tokenkey='unclassified'; stops[tokenkey]=(tokenkey,None,'Sin causa identificable en fuente',None,None,None,None,'sin_clasificar',False)
            stop_items.append((tokenkey,0,reported,'tiempo_total','Sin causa identificable en fuente'))
        if reported is not None and abs(detail_total-reported)>Decimal('0.02'): qc['downtime_reconciliation_abs_gt_0_02h']+=1
        if any(not x[4] or x[4]=='Sin clasificación en fuente' for x in stop_items): qc['legacy_unmapped_stop_rows']+=1
        records.append((excel_row,d,machine,shift,ref,cases,op_hours,nonwork,reported,stop_items))
    with psycopg.connect(DB) as con:
      with con.cursor() as cur:
        cur.execute("INSERT INTO dw.etl_audit(source_file,source_rows,accepted_rows,rejected_rows,downtime_events,quality_summary) VALUES(%s,%s,%s,%s,%s,%s::jsonb) RETURNING run_id",(os.path.basename(SOURCE),src_count,len(records),len(invalid),sum(len(r[-1]) for r in records),json.dumps(qc))); run_id=cur.fetchone()[0]
      con.commit()
    try:
      with psycopg.connect(DB) as con:
       with con.cursor() as cur:
        # The workbook is a source snapshot. Replacing both historical facts avoids stale
        # values when an operator corrects a row or inserts rows in the spreadsheet.
        cur.execute("SELECT pg_try_advisory_xact_lock(9042026)")
        if not cur.fetchone()[0]:
            raise RuntimeError('Ya hay una carga ETL del histórico en ejecución')
        cur.execute("TRUNCATE TABLE dw.fact_production CASCADE")
        dates={}
        for r in records:
            d=r[1]; dates[d]=(d.year*10000+d.month*100+d.day,d,MONTHS[d.month],(d.month-1)//3+1,d.isocalendar().week,d.weekday())
        for k,(full,d,mn,q,wk,wd) in dates.items(): cur.execute("INSERT INTO dw.dim_date VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT(date_key) DO NOTHING",(full,d,d.day,d.month,mn,q,d.year,wk,wd,d.strftime('%A'),wd>=5))
        for i in range(1,5): cur.execute("INSERT INTO dw.dim_machine(machine_code,machine_name,line_number) VALUES(%s,%s,%s) ON CONFLICT(machine_code) DO UPDATE SET machine_name=EXCLUDED.machine_name,line_number=EXCLUDED.line_number",(f'Vinilos_{i}',f'Vinilos {i}',i))
        shifts=sorted({r[3] for r in records})
        for s in shifts: cur.execute("INSERT INTO dw.dim_shift(shift_code,shift_name,shift_group) VALUES(%s,%s,%s) ON CONFLICT(shift_code) DO UPDATE SET shift_name=EXCLUDED.shift_name,shift_group=EXCLUDED.shift_group",(s,s,('turno '+s.split('Turno ')[-1] if 'Turno ' in s else 'sin clasificar')))
        for ref in sorted({r[4] for r in records}): cur.execute("INSERT INTO dw.dim_reference(reference_name) VALUES(%s) ON CONFLICT(reference_name) DO NOTHING",(ref,))
        for item in stops.values(): cur.execute("INSERT INTO dw.dim_stop(stop_source_token,stop_code,stop_label,subcode,subcode_label,impact_area,owner_group,hierarchy_level,is_mapped) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT(stop_source_token) DO UPDATE SET stop_code=EXCLUDED.stop_code,stop_label=EXCLUDED.stop_label,subcode=EXCLUDED.subcode,subcode_label=EXCLUDED.subcode_label,impact_area=EXCLUDED.impact_area,owner_group=EXCLUDED.owner_group,hierarchy_level=EXCLUDED.hierarchy_level,is_mapped=EXCLUDED.is_mapped",item)
        for rr,d,m,sh,ref,cases,op,nonwork,reported,stop_items in records:
          dk=d.year*10000+d.month*100+d.day
          cur.execute("SELECT machine_key FROM dw.dim_machine WHERE machine_code=%s",(m,)); mk=cur.fetchone()[0]
          cur.execute("SELECT shift_key FROM dw.dim_shift WHERE shift_code=%s",(sh,)); sk=cur.fetchone()[0]
          cur.execute("SELECT reference_key FROM dw.dim_reference WHERE reference_name=%s",(ref,)); rk=cur.fetchone()[0]
          cur.execute("INSERT INTO dw.fact_production(source_row_id,date_key,machine_key,shift_key,reference_key,cases_produced,operating_hours,reported_nonworking_hours,reported_downtime_hours,source_excel_row) VALUES(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT(source_row_id) DO NOTHING",(rr,dk,mk,sk,rk,cases,op,nonwork,reported,rr))
          for tk,slot,dur,ds,label in stop_items:
            cur.execute("SELECT stop_key FROM dw.dim_stop WHERE stop_source_token=%s",(tk,)); st=cur.fetchone()[0]
            cur.execute("INSERT INTO dw.fact_downtime(source_row_id,stop_key,source_slot,duration_hours,duration_source) VALUES(%s,%s,%s,%s,%s) ON CONFLICT(source_row_id,source_slot) DO NOTHING",(rr,st,slot,dur,ds))
       con.commit()
      with psycopg.connect(DB) as con:
       with con.cursor() as cur: cur.execute("UPDATE dw.etl_audit SET finished_at=now(),status='success' WHERE run_id=%s",(run_id,))
       con.commit()
    except Exception as exc:
      with psycopg.connect(DB) as con:
       with con.cursor() as cur: cur.execute("UPDATE dw.etl_audit SET finished_at=now(),status='failed',quality_summary=quality_summary || jsonb_build_object('error',left(%s,1000)) WHERE run_id=%s",(str(exc),run_id))
       con.commit()
      raise
    finally:
      wb.close()
    print(json.dumps({'run_id':run_id,'source_rows':src_count,'accepted':len(records),'rejected':len(invalid),'downtime_events':sum(len(r[-1]) for r in records),'quality':qc},ensure_ascii=False,indent=2))
if __name__=='__main__': main()

