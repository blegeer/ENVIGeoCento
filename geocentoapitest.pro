FUNCTION GeocentoSearch_Callback, status, progress, data

  
  ; Print the info msgs from the url object
  PRINT, status
  if (data ne !NULL) then print, data
  help, progress
  
  ; Return 1 to continue, return 0 to cancel
  RETURN, 1
END

PRO GeocentoAPITest, JSON=json_response

apiKey = 'n807cEukBtYz2TsVu8x0'
urlBase = 'https://earthimages.geocento.com'
apiEndpoint = '/api/search'
headers = ['Authorization: Token '+apiKey, $
  'Content-Type: application/json'] ; , $
  ; 'Accept: text/html']


queryHash = HASH('sensorFilters', HASH('maxResolution',0.5), $
     'aoiWKT','POLYGON((40 40, 20 45, 45 30, 40 40))',  $
     'start','1434672000', $
     'stop','1440972000')
     
queryData = json_serialize(queryHash)
 
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
geocento_searchResults, json_response

END

