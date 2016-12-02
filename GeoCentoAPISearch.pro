FUNCTION DateToSeconds, datestr

  ; take a date in the form 01/01/2015 and convert it to milliseconds appropriate for
  ; esri query routines
  parts = strsplit(datestr,'/', /extract)
  month = fix(parts[0])
  day = fix(parts[1])
  year = fix(parts[2])
  jDay = julday(month, day, year,23,59,59)

  ; what is the julday of january 1st, 1970 (second 0 in time)
  bDay = julday(1,1,1970,0,0,0)

  ; how many from the second 0 to the desired date
  days = ulong64(jDay) - ulong64(bDay)

  ; how many seconds
  seconds = days * 86400

  ; how many milliseconds
  mseconds = seconds * 1000
  return, seconds

END

FUNCTION GeocentoAPISearch_Callback, status, progress, data

  
  ; Print the info msgs from the url object
  PRINT, status
  if (data ne !NULL) then print, data
  help, progress
  
  ; Return 1 to continue, return 0 to cancel
  RETURN, 1
END

FUNCTION GeocentoAPISearch, AOIWKT=aoiAKT, $
  START=dstart, $
  STOP=dstop, $
  USeEXTENT=useextent, $
  MAXRES=maxres, $
  MINRES=minres ; , JSON=json_response

if (n_elements(maxres) ne 1) then maxRes = 2 ; meters
if (n_elements(minres) ne 1) then minRes = 0.5 ; meters

if (keyword_set(useextent)) then begin
  
  e = envi(/current)
  v = e.getView()
  
  ext = v.getExtent(/GEO)
  minlon = strtrim(ext[0],2)
  maxlon = strtrim(ext[4],2)
  minlat = strtrim(ext[1],2)
  maxlat = strtrim(ext[5],2)
  aoiWKT = 'POLYGON(('
  aoiWKT+= minlon+' '+minlat
  aoiWKT+= ','+maxlon+' '+minlat
  aoiWKT+= ','+maxlon+' '+maxlat
  aoiWKT+= ','+minlon+' '+maxlat
  aoiWKT+= ','+minlon+' '+minlat+'))'
  print, aoiWKT
  
endif

if (aoiWKT eq !NULL) then begin
  message, 'ERROR: no AOI passed or determined by extent'
  return, !NULL
endif

if (n_elements(dstop) ne 1) then begin
  ; 7 days ago
  caldat, systime(/julian)-7, m, d, y
  m = m lt 10 ? '0'+strtrim(m,2) : strtrim(m,2)
  d = d lt 10 ? '0'+strtrim(d,2) : strtrim(d,2)
  y = strtrim(y,2)
  dstop = DateToSeconds(m+'/'+d+'/'+y)
endif else dstop = DateToSeconds(dStop)

if (n_elements(dstart) ne 1) then begin
  ; 14 days ago
  caldat, systime(/julian)-14, em,ed, ey
  em = em lt 10 ? '0'+strtrim(em,2) : strtrim(em,2)
  ed = ed lt 10 ? '0'+strtrim(ed,2) : strtrim(ed,2)
  ey = strtrim(ey,2)
  dstart = DateToSeconds(em+'/'+ed+'/'+ey)
endif else dstart = DateToSeconds(dstart)

apiKey = 'n807cEukBtYz2TsVu8x0'
urlBase = 'https://earthimages.geocento.com'
apiEndpoint = '/api/search'
headers = ['Authorization: Token '+apiKey, $
  'Content-Type: application/json'] ; , $
  ; 'Accept: text/html']


queryHash = HASH('sensorFilters', HASH('maxResolution',maxRes, 'minResolution', minRes), $
     'aoiWKT',aoiWKT,  $
     'start',dstart, $
     'stop',dstop)
     
queryData = json_serialize(queryHash)
print, queryData
 
url=urlBase+apiEndpoint
  

oURL = IDLNetURL(HEADERS=headers, $
  SSL_VERIFY_HOST=0, $
  SSL_VERIFY_PEER=0)
  
;queryData = '{}'  
j = oURL.Put(queryData, /BUFFER, URL=url, /POST)
oURL = !NULL

openr, lun, j, /GET_LUN
str = ''
readf, lun, j
free_lun, lun

json_response = json_parse(j, /TOSTRUCT)
return, json_response

; geocento_searchResults, json_response

END

