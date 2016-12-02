FUNCTION GetURLThumbnail, url

oURL = IDLNetURL( $
  SSL_VERIFY_HOST=0, $
  SSL_VERIFY_PEER=0)
rawImg = oURL->Get(URL=url, /BUFFER)
help, rawImg

fTmp=filepath('tmp'+strtrim(long64(systime(1)),2)+'.dat', /TMP)
openw, lun, fTmp, /GET_LUN
writeu, lun, rawImg
free_lun, lun
img = read_image(fTmp)
file_delete, fTmp

return, img
  
END