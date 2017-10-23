
oash=$(find /opt -type f -name omsadmin.sh)

xcwsid1=d5c5daef-bd37-40cf-a3f5-58b717482f7f
xcskey1='aijzZOFc+5rPSzPLH+NxVv5pRAc68k6j/HiJdzwAvAZVy0ABrC46LasMLP/+uwHJPZD9QutHy9cu7lxvzBacTg=='
xcomsd1=opinsights.azure.com
xcwsname1=xcworkspace0003
xcwsid2=2b5cfa29-0626-4f6a-8cf7-935d5359ab63
xcskey2='LAhhQY6uElqebuspbEU0W/nxXcsotM5KhqoiexTL/f4BNMxk7/KoZc03Fp3i85JgdwxydKPr6ot96ubWD4zADg=='
xcomsd2=opinsights.azure.com
xcwsname2=xcworkspace0011
xcwsid3=97adb474-1a30-4a02-9c62-af4df739952d
xcskey3='O15sMKqhKiLCxNIzvKmPmqvtIvtzt+NxyaVuVBePNpFcihh+rcIKnKXn2Yb6ah7Fz0UGrYKyE3EvP4FPTO1Hbw=='
xcomsd3=opinsights.azure.com
xcwsname3=xcworkspace0012
xcwsid4=22e11080-b92d-4ed2-8655-a1efe3b4c28d
xcskey4='qF9/5SA9+9Bf1H0Mddag2+i9chlAi2wz8iL9VdWEwhKwYg5xqcCfDv6R6HZp8SaZ+DuuR4Djfiy+l0lKjw6Sag=='
xcomsd4=opinsights.azure.com
xcwsname4=xcworkspace0013
xcwsid5=f0468289-42bc-456a-be5e-ca393e882c75
xcskey5='km3hVGGL1+WbSAK8/ymjtaKh5zc0ogtN/fLD4O8mN6xBN6HcYf6w2micbtXPOMK2h5DCXYh6oH62u1uB2SzveQ=='
xcomsd5=opinsights.azure.com
xcwsname5=xcworkspace0014
sudo $oash -w $xcwsid1 -s $xcskey1 -d $xcomsd1
sudo $oash -w $xcwsid2 -s $xcskey2 -d $xcomsd2
sudo $oash -w $xcwsid3 -s $xcskey3 -d $xcomsd3
sudo $oash -w $xcwsid4 -s $xcskey4 -d $xcomsd4
sudo $oash -w $xcwsid5 -s $xcskey5 -d $xcomsd5
