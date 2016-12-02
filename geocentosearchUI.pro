FUNCTION DateFromUnixTime, uTime

caldat, ((uTime*0.001) / 86400.0 ) + 2440587.5, m , d, y
return, strtrim(m,2)+'/'+strtrim(d,2)+'/'+strtrim(y,2)

END

PRO GeoCentoSearchUI_OverlayFootprints, json, cData

  e = envi(/current)
  
  

  if (n_elements(json.products) gt 0) then begin

    ; remove the current overlay
    GeoCentoSearchUI_RemoveOutline, cData

    ; create a new shapefile overlay
    tFileName = e.GetTemporaryFilename('SHP')
    ;
    oShp = obj_new('IDLffShape', tfileName, ENTITY_TYPE=5, /UPDATE)
    oShp->AddAttribute, 'ProductID', 7, 50, PRECISION=0
    oShp->AddAttribute, 'Type', 7, 25, PRECISION=0
    oShp->AddAttribute, 'Date', 7, 25, PRECISION=0
    oShp->AddAttribute, 'SatelliteName', 7, 25, PRECISION=0
    oShp->AddAttribute, 'InstrumentName', 7, 25, PRECISION=0
    oShp->AddAttribute, 'SensorType', 7, 25, PRECISION=0
    oShp->AddAttribute, 'SensorBand', 7, 25, PRECISION=0
    oShp->AddAttribute, 'SensorResolution', 5, 12, PRECISION=2
    oShp->AddAttribute, 'CloudCoveragePercent', 5, 20, PRECISION=2
        
    pIDX = 0L

    for i=0, n_elements(json.products)-1 do begin

      p=json.products[i]
      coords = p.coordinateswkt
      exp = stregex(coords, 'POLYGON\(\((.*)\)\)', /subex, /extract)
      pairs = strsplit(exp[1],',',/EXTRACT)
      
      darr = dblarr(2,n_elements(pairs))
      for j=0,n_elements(pairs)-1 do begin
          ltln = strsplit(pairs[j],' ', /extract)
          darr[0,j]=ltln[0]
          darr[1,j]=ltln[1]
      endfor

        ent={IDL_SHAPE_ENTITY}
        ent.SHAPE_TYPE=5
        ent.BOUNDS=[min(darr[0,*]),min(darr[1,*]),0,0,max(darr[0,*]),max(darr[0,*]),0,0]
        ent.N_VERTICES=n_elements(pairs)
        ent.VERTICES=ptr_new(darr)
        ent.N_PARTS=0
        oShp->PutEntity, ent
        attr=oShp->GetAttributes(/ATTRIBUTE_STRUCTURE)
        attr.ATTRIBUTE_0=strtrim(p.productid,2)
        attr.ATTRIBUTE_1=strtrim(p.type,2)
        attr.ATTRIBUTE_3=strtrim(p.satellitename,2)
        attr.ATTRIBUTE_2=strtrim(DateFromUnixTime(p.start),2)
        attr.ATTRIBUTE_4=strtrim(p.instrumentname,2)
        attr.ATTRIBUTE_5=strtrim(p.sensortype,2)
        attr.ATTRIBUTE_6=strtrim(p.sensorband,2)
        attr.ATTRIBUTE_7=p.sensorresolution
        attr.ATTRIBUTE_8=p.cloudcoveragepercent
        
        oShp.SetAttributes, pIdx, attr
        pIdx++

     
    endfor
    
    ; create the shapefile
    oShp->close
    obj_destroy, oShp


    e.Refresh, /DISABLE
    v=e.getView()
    vec=e.OpenVector(tfileName)
    l=v.createLayer(vec, ERROR = err)
    if (err ne '') then begin
      a = dialog_message(['Cannot load footprint layers',err])
      return
    endif
    l.color='blue'
    l.fill_interior = 1
    l.fill_color = [127,127,127]
    l.transparency = 25

    l->SetProperty, NAME='Query Results'
    e.Refresh

    cdata.curOverlayShapefile = tFileName
    cdata.curOverlayVectorLayer = vec

  endif

END

PRO GeoCentoSearchUI_RemoveOutline, cdata

  if (cData.curOverlayVectorLayer ne !NULL) then begin

    cData.curOverlayVectorLayer.Close
    cData.curOverlayVectorLayer = obj_new()

    ;if (file_test(self.curOverlayShapeFile, /WRITE)) then begin
    ;  file_delete, self.curOverlayShapefile
    ;endif
    cdata.curOverlayShapefile = ''

  endif

END

PRO GeoCentoSearchUI_ActiveQuery, event

widget_control, event.top, GET_UVALUE = cData
if (event.select) then begin
  cData.activeQuery = !TRUE
  widget_control, cData.timerID, TIMER = 1
endif else begin
  cData.activeQuery = !FALSE
endelse

END

PRO GeoCentoSearchUI_Update, event

widget_control, event.top, GET_UVALUE = cData

e = envi(/current)
v = e.getView()
if (v.getLayer() eq !NULL) then begin
  a = dialog_message('ERROR no layers added to display')
  return
endif

ext = v.getExtent(/GEO)
if (not array_equal(ext, cData.curExtent)) then begin
  cData.curExtent = ext
  
  widget_control, cData.sTimeText, GET_VALUE = sTime
  widget_control, cData.sTimeText, GET_VALUE = eTime
  widget_control, cData.minResText, GET_VALUE = minRes
  widget_control, cData.maxResText, GET_VALUE = maxRes
  
  json = GeoCentoAPISearch(/USEEXTENT, $
    START=strtrim(sTime[0],2), $
    STOP=strtrim(eTime[0],2), $
    MINRES=float(minRes[0]), $
    MAXRES=float(maxRes[0]))
    
  
  if (json.products.count() eq 0) then begin
    a = dialog_message('No Results Returned from Search')
    return
  endif
  cdata.products = json.products
  
  
  tData = GeoCentoSearchUI_CreateTableData(json)
  widget_control, cData.mainTable, TABLE_YSIZE=n_elementS(tData)
  widget_control, cData.mainTable, SET_VALUE = tData
  GeoCentoSearchUI_OverlayFootprints, json, cData
  
endif
if (cData.activeQuery) then widget_control, cData.timerID, TIMER = 1

END

PRO GeoCentoSearchUI_Resize, event


widget_control, event.top, GET_UVALUE = cData
g = widget_info(event.top, /GEOMETRY)
gBottom = widget_info(cData.bottomBase, /GEOMETRY)
widget_control, cData.mainTable, SCR_XSIZE=event.x - (2*g.xpad), SCR_YSIZE=event.y - (2*g.ypad) - gBottom.scr_ysize

END

PRO GeoCentoSearchUI_Table, event

  compile_opt idl2
  
  widget_control, event.top, GET_UVALUE = cData
  ; what is the length of the table
  tableLen = 10 ; n_tags(cdata.products[0])
  
  if (event.type eq 4) then begin
    
    if (event.sel_top eq event.sel_bottom) and (event.sel_left eq 0) and (event.sel_right eq (tableLen-1)) then begin
        
        e = envi(/current)
        
        p = cData.products[event.sel_top]
        print, p.ql
        oRaster = e.openRaster(p.ql, ERROR = openError)
        if (openError ne '') then begin
          print, 'ERROR opening WMS: '+p.ql
          print, openError
        endif else begin
          oView = e.getView()
          oLayer = oView.createLayer(oRaster)  
        endelse
        
        imgFile = geturlthumbnail(p.thumbnail)
        title = p.providername+' '+p.satellitename+' '+strtrim(p.sensorresolution*100.0)+'cm ('+DateFromUnixTime(p.start)+')'
        i = image(imgfile, TITLE=title, WINDOW_TITLE=p.providername+' '+p.satellitename)
        
    endif
  endif
  
END

PRO  GeoCentoSearchUI_Query, event
  
   widget_control, event.top, GET_UVALUE = cData
   cData.curExtent = fltarr(8)
   GeoCentoSearchUI_Update, event

END


FUNCTION GeoCentoSearchUI_CreateTableData, json

 sampleRes = json.products[0]

  
  tableData = replicate({GEOCENTOTABLE}, n_elements(json.products))

  for i=0,n_elements(json.products)-1 do begin
    t = json.products[i]
    res = string(t.sensorresolution, FORMAT='(F4.2)')+' meters'
    date = DateFromUnixTime( t.start)
    cloudcover = string(t.cloudcoveragepercent, FORMAT='(f5.2)')+'%'
    if (t.type ne 'TASKING') then begin
      price =  strtrim(t.selectionprice.value,2)+' '+t.selectionprice.currency
    endif else begin
      price = 'TASKING'
    endelse
    
    tableData[i] = {GEOCENTOTABLE,t.providername, t.type, t.satellitename, t.instrumentname, t.sensortype, t.sensorband, res, date, cloudcover, price}
  endfor
  
  
  return, tableData
  
END

PRO GeoCentoSearchUI


tableStruct = {GEOCENTOTABLE, providername:'', $
  type:'', $
  satellitename:'', $
  instrumentname:'', $
  sensortype:'',$
  sensorband:'', $
  sensorresolution: '', $
  date:'', $
  cloudcover:'', $
  price:''}
  
  ; today
  caldat, systime(/julian), m, d, y
  m = m lt 10 ? '0'+strtrim(m,2) : strtrim(m,2)
  d = d lt 10 ? '0'+strtrim(d,2) : strtrim(d,2)
  y = strtrim(y,2)

  ; 7 days ago
  caldat, systime(/julian)-7, em,ed, ey
  em = em lt 10 ? '0'+strtrim(em,2) : strtrim(em,2)
  ed = ed lt 10 ? '0'+strtrim(ed,2) : strtrim(ed,2)
  ey = strtrim(ey,2)
   

 tlb = widget_base(TITLE = 'GeoCento Testing', /COLUMN, /TLB_SIZE_EVENTS) 
mainBase = widget_base(tlb, /COLUMN, EVENT_PRO = 'GeoCentoSearchUI_Update')   ; timer
mainTable = widget_table(mainBase, $
  SCR_XSIZE=600, SCR_YSIZE=400, $
  XSIZE=n_tags(tableStruct), YSIZE=n_elements(40), $
  COLUMN_LABELS = tag_names(tableStruct), $
  /ROW_MAJOR, $
  /SCROLL, $
  /RESIZeABLE_COLUMNS, $
  /ALL_EVENTS, $
  EVENT_PRO='GeoCentoSearchUI_Table')
  
bottomBase = widget_base(tlb, /ROW)

queryParamsRow = widget_base(bottomBase, /FRAME, /ROW)
sTimeLabel = widget_label(queryParamsRow, VALUE = 'Start Date (MM/DD/YY): ')
sTimeText = widget_text(queryParamsRow, VALUE = em+'/'+ed+'/'+ey, /EDITABLE, YSIZE=1, XSIZE=10, EVENT_PRO='GeoCentoSearchUI_Query')
eTimeLabel = widget_label(queryParamsRow, VALUE = 'End Date (MM/DD/YY): ')
eTimeText = widget_text(queryParamsRow, VALUE = m+'/'+d+'/'+y, /EDITABLE, YSIZE=1, XSIZE=10, EVENT_PRO='GeoCentoSearchUI_Query')
minResLabel = widget_label(queryParamsRow, VALUE='Min Resolution (m): ')
minResText = widget_text(queryParamsRow, VALUE = '0.5', /EDITABLE, YSIZE=1, XSIZE=6, EVENT_PRO='GeoCentoSearchUI_Query')
maxResLabel = widget_label(queryParamsRow, VALUE='Max Resolution (m): ')
maxResText = widget_text(queryParamsRow, VALUE = '1.0', /EDITABLE, YSIZE=1, XSIZE=6, EVENT_PRO='GeoCentoSearchUI_Query')


queryButton = widget_button(bottomBase, VALUE = 'Query', EVENT_PRO='GeoCentoSearchUI_Query')
activeQueryBase = widget_base(bottomBase, /NONEXCLUSIVE)
activeQueryButton = widget_button(activeQueryBase, VALUE = 'Active Query', EVENT_PRO='GeoCentoSearchUI_ActiveQuery')

widget_control, tlb, /REALIZE


cData = DICTIONARY("mainTable", mainTable, $
  "timerID", mainBase, $
  "curExtent", fltarr(8), $
  "sTimeText", sTimeText, $
  "eTimeText", eTimeText, $
  "minResText", minResText, $
  "maxResText", maxResText, $
  "bottomBase", bottomBase, $  
  "activeQuery", !FALSE, $
  "curOverlayShapefile", "", $
  "curOverlayVectorLayer", obj_new() $
  )
widget_control, tlb, SET_UVALUE = cData
if (cData.activeQuery) then widget_control, mainBase, TIMER = 1

Xmanager, 'GeoCentoSearchUI', tlb, /NO_BLOCK, EVENT_HANDLER='GeoCentoSearchUI_Resize'



END
  
  