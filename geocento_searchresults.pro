FUNCTION DateFromUnixTime, uTime

caldat, ((uTime*0.001) / 86400.0 ) + 2440587.5, m , d, y
return, strtrim(m,2)+'/'+strtrim(d,2)+'/'+strtrim(y,2)

END

PRO GeoCento_SearchResultsResize, event


widget_control, event.top, GET_UVALUE = cData
g = widget_info(event.top, /GEOMETRY)
widget_control, cData.mainTable, SCR_XSIZE=event.x - (2*g.xpad), SCR_YSIZE=event.y - (2*g.ypad)

END

PRO GeoCento_SearchResultsTable, event

  compile_opt idl2
  
  widget_control, event.top, GET_UVALUE = cData
  
  if (event.type eq 4) then begin
    if (event.sel_top eq event.sel_bottom) then begin
        i = image(geturlthumbnail(cData.products[event.sel_top].thumbnail))
    endif
  endif
  
END

PRO GeoCento_SearchResults, json

sampleRes = json.products[0]

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
  

tableData = replicate({GEOCENTOTABLE}, n_elements(json.products)) 

for i=0,n_elements(json.products)-1 do begin
  t = json.products[i]
  res = string(t.sensorresolution, FORMAT='(F4.2)')+' meters'
  date = DateFromUnixTime( t.start)
  cloudcover = string(t.cloudcoveragepercent, FORMAT='(f5.2)')+'%'
  price = strtrim(t.selectionprice.value,2)+' '+t.selectionprice.currency
  tableData[i] = {GEOCENTOTABLE,t.providername, t.type, t.satellitename, t.instrumentname, t.sensortype, t.sensorband, res, date, cloudcover, price}  
endfor


tlb = widget_base(TITLE = 'GeoCento Testing', /COLUMN, /TLB_SIZE_EVENTS)
mainBase = widget_base(tlb, /ROW)
mainTable = widget_table(mainBase, $
  SCR_XSIZE=600, SCR_YSIZE=400, $
  XSIZE=n_tags(tableStruct), YSIZE=n_elements(json.products), $
  COLUMN_LABELS = tag_names(tableStruct), $
  /ROW_MAJOR, $
  /SCROLL, $
  /RESIZeABLE_COLUMNS, $
  /ALL_EVENTS, $
  EVENT_PRO='GeoCento_SearchResultsTable')
widget_control, tlb, /REALIZE

cData = DICTIONARY("mainTable", mainTable, "products", json.products)
widget_control, tlb, SET_UVALUE = cData

widget_control, mainTable, SET_VALUE = tableData

Xmanager, 'GeoCento_SearchResults', tlb, /NO_BLOCK, EVENT_HANDLER='GeoCento_SearchResultsResize'






END
  
  