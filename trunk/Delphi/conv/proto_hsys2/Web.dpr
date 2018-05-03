program [[ProjectName]];

{
  xxm 'skip the handler'
  HTTPAPI v2 dedicated exe from xxm project

  Usage:
    xxmConv /proto <path to these files> /x:XxmSourcePath <path to xxm source> /src <path to new folder for generated code> <path to xxm project>

  Rember to set up version info on the resulting project.

  $Rev$ $Date$
}

{$R '[[XxmSourcePath]]\common\xxmData.res' '[[XxmSourcePath]]\common\xxmData.rc'}
{$IFNDEF HSYS2}{$MESSAGE FATAL 'HSYS2 not defined.'}{$ENDIF}

[[ProjectSwitches]]
uses
  SysUtils,
  xxm in '[[XxmSourcePath]]\bin\public\xxm.pas',
  xxmHSys2Run in '[[XxmSourcePath]]\hsys\xxmHSys2Run.pas',
  httpapi2 in '[[XxmSourcePath]]\hsys\httpapi2.pas',
  xxmHSysMain in '[[XxmSourcePath]]\hsys\xxmHSysMain.pas',
  xxmParams in '[[XxmSourcePath]]\common\xxmParams.pas',
  xxmParUtils in '[[XxmSourcePath]]\common\xxmParUtils.pas',
  xxmHeaders in '[[XxmSourcePath]]\bin\public\xxmHeaders.pas',
  xxmThreadPool in '[[XxmSourcePath]]\common\xxmThreadPool.pas',
  xxmPReg in '[[XxmSourcePath]]\common\xxmPReg.pas',
  xxmPRegJson in '[[XxmSourcePath]]\conv\xxmPRegJson.pas', //ATTENTION: rigged for single project
  xxmCommonUtils in '[[XxmSourcePath]]\common\xxmCommonUtils.pas',
  xxmContext in '[[XxmSourcePath]]\common\xxmContext.pas',
  xxmHSysHeaders in '[[XxmSourcePath]]\hsys\xxmHSysHeaders.pas',
  [[@Include]][[IncludeUnit]] in '[[ProjectPath]][[IncludePath]][[IncludeUnit]].pas',
  [[@]][[@Fragment]][[FragmentUnit]] in '[[FragmentPath]][[FragmentUnit]].pas', {[[FragmentAddress]]}
  [[@]][[UsesClause]]
  xxmp in '[[ProjectPath]]xxmp.pas';

{$R *.RES}

[[ProjectHeader]]
begin
  XxmProjectName:='[[ProjectName]]';
  [[ProjectBody]]
  XxmRunHSys(HandleWindowsMessages);
end.
