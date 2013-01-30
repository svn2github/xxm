@echo off
cd conv
dcc32 xxmConv.dpr
dcc32 xxmProject.dpr
cd ..\proto
dcc32 xxmProto.dpr
cd ..\run
dcc32 xxmRun.dpr
cd ..\http
dcc32 xxmHttpAU.dpr
dcc32 xxmHttpDev.dpr
dcc32 xxmHttpSvc.dpr
dcc32 xxmHttpSvcAU.dpr
dcc32 xxmHttp.dpr
cd ..\local
dcc32 xxmLocal.dpr
dcc32 xxmLocalAU.dpr
dcc32 xxmLocalDev.dpr
cd ..\isapi
dcc32 xxmIsapiAU.dpr
dcc32 xxmIsapiDev.dpr
dcc32 xxmIsapiEx.dpr
cd ..\cgi
dcc32 xxmCGI.dpr
dcc32 xxmHost.dpr
dcc32 xxmHostAU.dpr
dcc32 xxmHostDev.dpr
dcc32 xxmHostSvc.dpr
dcc32 xxmHostSvcAU.dpr
cd ..\apache
dcc32 xxmAhttpd.dpr
dcc32 xxmAhttpdAU.dpr
dcc32 xxmAhttpdDev.dpr
cd ..\hsys
dcc32 xxmHSys1.dpr
dcc32 xxmHSys1AU.dpr
dcc32 xxmHSys1Dev.dpr
dcc32 xxmHSys1Svc.dpr
dcc32 xxmHSys1SvcAU.dpr
dcc32 xxmHSys2.dpr
dcc32 xxmHSys2AU.dpr
dcc32 xxmHSys2Dev.dpr
dcc32 xxmHSys2Svc.dpr
dcc32 xxmHSys2SvcAU.dpr
cd ..\synapse
dcc32 xxmSynaAU.dpr
dcc32 xxmSyna.dpr
dcc32 xxmSynaSvcAU.dpr
dcc32 xxmSynaSvc.dpr
dcc32 xxmSynaDev.dpr
cd ..\gecko
dcc32 xxmGecko.dpr
dcc32 xxmGeckoAU.dpr
dcc32 xxmGeckoDev.dpr
cd setup
make_xxmGeckoDev_xpi.cmd
cd ..\..
pause