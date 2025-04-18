// *************************************************************************** }
//
// LoggerPro
//
// Copyright (c) 2010-2025 Daniele Teti
//
// https://github.com/danieleteti/loggerpro
//
// ***************************************************************************
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// ***************************************************************************

unit LoggerPro;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  System.Classes,
  ThreadSafeQueueU, System.SysUtils;

var
  DefaultLoggerProMainQueueSize: Cardinal = 50000;
  DefaultLoggerProAppenderQueueSize: Cardinal = 50000;

type
  TLogType = (Debug = 0, Info, Warning, Error, Fatal);
  TLogErrorReason = (QueueFull);
  TLogErrorAction = (SkipNewest, DiscardOlder);
  TLogExtendedInfo = (EIUserName, EIComputerName, EIProcessName, EIProcessID, EIDeviceID { mobile });
  TLoggerProExtendedInfo = set of TLogExtendedInfo;

  { @abstract(Represent the single log item)
    Each call to some kind of log method is wrapped in a @link(TLogItem)
    instance and passed down the layour of LoggerPro. }
  TLogItem = class sealed
  private
    FType: TLogType;
    FMessage: string;
    FTag: string;
    FTimeStamp: TDateTime;
    FThreadID: TThreadID;
    function GetLogTypeAsString: string;
  public
    constructor Create(const aType: TLogType; const aMessage: string; const aTag: string); overload;
    constructor Create(const aType: TLogType; const aMessage: string; const aTag: string; const aTimeStamp: TDateTime;
      const aThreadID: TThreadID); overload;

    function Clone: TLogItem;
    { @abstract(The type of the log)
      Log can be one of the following types:
      @unorderedlist(
      @item(DEBUG)
      @item(INFO)
      @item(WARNING)
      @item(ERROR)
      @item(FATAL)
      ) }
    property LogType: TLogType read FType;
    { @abstract(The text of the log message) }
    property LogMessage: string read FMessage;
    { @abstract(The tag of the log message) }
    property LogTag: string read FTag;
    { @abstract(The timestamp when the @link(TLogItem) is generated) }
    property TimeStamp: TDateTime read FTimeStamp;
    { @abstract(The IDof the thread which generated the log item) }
    property ThreadID: TThreadID read FThreadID;
    { @abstract(The type of the log converted in string) }
    property LogTypeAsString: string read GetLogTypeAsString;
  end;

  ILogItemRenderer = interface
    ['{CBD22D22-C387-4A97-AD5D-4945B812FDB0}']
    procedure Setup;
    procedure TearDown;
    function RenderLogItem(const aLogItem: TLogItem): String;
  end;

  TLoggerProAppenderErrorEvent = reference to procedure(const AppenderClassName: string; const aFailedLogItem: TLogItem;
    const Reason: TLogErrorReason; var Action: TLogErrorAction);

  TLoggerProEventsHandler = class sealed
  public
    OnAppenderError: TLoggerProAppenderErrorEvent;
  end;

  { @abstract(Interface implemented by all the classes used as appenders) }
  ILogAppender = interface
    ['{58AFB557-C594-4A4B-8DC9-0F13B37F60CB}']
    { @abstract(This method is internally called by LoggerPro to initialize the appender) }
    procedure Setup;
    { @abstract(This method is called at each log item represented by @link(TLogItem))
      The appender should be as-fast-as-it-can to handle the message, however
      each appender runs in a separated thread. }
    procedure WriteLog(const aLogItem: TLogItem);
    { @abstract(This method is internally called by LoggerPro to deinitialize the appender) }
    procedure TearDown;
    // { @abstract(Enable or disable the log appender. Is used internally by LoggerPro but must be
    // implemented by each logappender. A simple @code(if enabled then dolog) is enough }
    // procedure SetEnabled(const Value: Boolean);
    // { @abstract(Returns if the logappender is currently enabled or not. }
    // function IsEnabled: Boolean;
    { @abstract(Set a custom log level for this appender. This value must be lower than the global LogWriter log level. }
    procedure SetLogLevel(const Value: TLogType);
    { @abstract(Get the loglevel for the appender. }
    function GetLogLevel: TLogType;
    { @abstract(If the appender is disabled, this method is called at each new
      logitem. This method should not raise exceptions and should try to restart the appender
      at specified time and only if some appropriate seconds/miutes are elapsed between the
      LastErrorTimestamp. }
    procedure TryToRestart(var Restarted: Boolean);

    procedure SetLastErrorTimeStamp(const LastErrorTimeStamp: TDateTime);
    function GetLastErrorTimeStamp: TDateTime;
    property LastErrorTimeStamp: TDateTime read GetLastErrorTimeStamp write SetLastErrorTimeStamp;
  end;

  ELoggerPro = class(Exception)

  end;

  TAppenderQueue = class(TThreadSafeQueue<TLogItem>)
  end;

  ICustomLogWriter = interface
    ['{8BC2F462-E2A3-4117-BE1F-03EB31997BB4}']
    function GetAppendersClassNames: TArray<string>;
    function GetAppenders(const aIndex: Integer): ILogAppender;
    property Appenders[const aIndex: Integer]: ILogAppender read GetAppenders;
    procedure AddAppender(const aAppenders: ILogAppender);
    procedure DelAppender(const aAppenders: ILogAppender);
    function AppendersCount(): Integer;

    // Base logging method
    procedure Log(const aType: TLogType; const aMessage: string; const aTag: string); overload;
  end;

  ILogWriter = interface(ICustomLogWriter)
    ['{A717A040-4493-458F-91B2-6F6E2AFB496F}']
    procedure Debug(const aMessage: string; const aTag: string); overload;
    procedure Debug(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Info(const aMessage: string; const aTag: string); overload;
    procedure Info(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Warn(const aMessage: string; const aTag: string); overload;
    procedure Warn(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Error(const aMessage: string; const aTag: string); overload;
    procedure Error(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Fatal(const aMessage: string; const aTag: string); overload;
    procedure Fatal(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Log(const aType: TLogType; const aMessage: string; const aTag: string); overload;
    procedure Log(const aType: TLogType; const aMessage: string; const aParams: array of const; const aTag: string); overload;

    procedure Disable;
    procedure Enable;
  end;

  TLogAppenderList = TList<ILogAppender>;

  TAppenderThread = class(TThread)
  private
    FLogAppender: ILogAppender;
    FAppenderQueue: TAppenderQueue;
    FFailing: Boolean;
    procedure SetFailing(const Value: Boolean);
  protected
    procedure Execute; override;

    type
      TAppenderStatus = (BeforeSetup, Running, WaitAfterFail, ToRestart, BeforeTearDown);
  public
    constructor Create(aLogAppender: ILogAppender; aAppenderQueue: TAppenderQueue);
    property Failing: Boolean read FFailing write SetFailing;
  end;

  TLoggerThread = class(TThread)
  private type
      TAppenderAdapter = class
      private
        FAppenderQueue: TAppenderQueue;
        FAppenderThread: TAppenderThread;
        FLogAppender: ILogAppender;
        FFailsCount: Cardinal;
      public
        constructor Create(aAppender: ILogAppender); virtual;
        destructor Destroy; override;
        function EnqueueLog(const aLogItem: TLogItem): Boolean;
        property Queue: TAppenderQueue read FAppenderQueue;
        property FailsCount: Cardinal read FFailsCount;
        function GetLogLevel: TLogType;
      end;

      TAppenderAdapterList = class(TObjectList<TAppenderAdapter>)
      public
        constructor Create;
      end;

  private
    FQueue: TThreadSafeQueue<TLogItem>;
    FAppenders: TLogAppenderList;
    FEventsHandlers: TLoggerProEventsHandler;
    FAppendersDecorators: TObjectList<TAppenderAdapter>;
    function BuildAppenderAdapters: TAppenderAdapterList;
    procedure DoOnAppenderError(const FailAppenderClassName: string; const aFailedLogItem: TLogItem; const aReason: TLogErrorReason;
      var aAction: TLogErrorAction);
    procedure SetEventsHandlers(const Value: TLoggerProEventsHandler);
  protected
    procedure Execute; override;
    procedure DoTerminate; override;
  public
    constructor Create(aAppenders: TLogAppenderList);
    destructor Destroy; override;

    property EventsHandlers: TLoggerProEventsHandler read FEventsHandlers write SetEventsHandlers;
    property LogWriterQueue: TThreadSafeQueue < TLogItem > read FQueue;
  end;

  TLoggerProInterfacedObject = class(TInterfacedObject)
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  end;

  TCustomLogWriter = class(TLoggerProInterfacedObject, ICustomLogWriter)
  strict private
    FLoggerThread: TLoggerThread;
    FLogAppenders: TLogAppenderList;
    FFreeAllowed: Boolean;
    FLogLevel: TLogType;
    function GetAppendersClassNames: TArray<string>;
  protected
    FEnabled: Boolean;
    procedure Initialize(const aEventsHandler: TLoggerProEventsHandler);
  public
    constructor Create(const aLogLevel: TLogType = TLogType.Debug); overload;
    constructor Create(const aLogAppenders: TLogAppenderList; const aLogLevel: TLogType = TLogType.Debug); overload;
    destructor Destroy; override;

    function GetAppenders(const aIndex: Integer): ILogAppender;
    procedure AddAppender(const aAppender: ILogAppender);
    procedure DelAppender(const aAppender: ILogAppender);
    function AppendersCount(): Integer;

    procedure Log(const aType: TLogType; const aMessage: string; const aTag: string); overload;
  end;

  TLogWriter = class(TCustomLogWriter, ILogWriter)
  public
    procedure Debug(const aMessage: string; const aTag: string); overload;
    procedure Debug(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Info(const aMessage: string; const aTag: string); overload;
    procedure Info(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Warn(const aMessage: string; const aTag: string); overload;
    procedure Warn(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Error(const aMessage: string; const aTag: string); overload;
    procedure Error(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Fatal(const aMessage: string; const aTag: string); overload;
    procedure Fatal(const aMessage: string; const aParams: array of TVarRec; const aTag: string); overload;

    procedure Log(const aType: TLogType; const aMessage: string; const aParams: array of const; const aTag: string); overload;

    procedure Disable;
    procedure Enable;
  end;

  TOnAppenderLogRow = reference to procedure(const LogItem: TLogItem; out LogRow: string);

  TLoggerProAppenderBase = class abstract(TInterfacedObject, ILogAppender)
  private
    FLogLevel: TLogType;
    FLastErrorTimeStamp: TDateTime;
    FFormatSettings: TFormatSettings;
  protected
    FOnLogRow: TOnAppenderLogRow;
    FLogItemRenderer: ILogItemRenderer;
    property FormatSettings: TFormatSettings read FFormatSettings;
    property LogItemRenderer: ILogItemRenderer read FLogItemRenderer;
  public
    constructor Create(ALogItemRenderer: ILogItemRenderer); overload; virtual;
    constructor Create; overload; virtual;
    procedure Setup; virtual;
    function FormatLog(const ALogItem: TLogItem): string; virtual;
    procedure WriteLog(const aLogItem: TLogItem); virtual; abstract;
    procedure TearDown; virtual;
    procedure TryToRestart(var Restarted: Boolean); virtual;
    procedure SetLogLevel(const Value: TLogType);
    function GetLogLevel: TLogType; inline;
    procedure SetLastErrorTimeStamp(const Value: TDateTime);
    function GetLastErrorTimeStamp: TDateTime;
    property LogLevel: TLogType read GetLogLevel write SetLogLevel;
    property OnLogRow: TOnAppenderLogRow read FOnLogRow write FOnLogRow;
  end;

  { @abstract(Builds a new ILogWriter instance. Call this global function to start logging like a pro.)
    Here's a sample unit that you can use in your code
    @longcode(#
    unit LoggerProConfig;

    interface

    uses
    LoggerPro;

    function Log: ILogWriter;

    implementation

    uses
    LoggerPro.FileAppender;

    var
    _Log: ILogWriter;

    function Log: ILogWriter;
    begin
    Result := _Log;
    end;

    initialization

    //If you need other appenders, feel free to add them here in the array
    _Log := BuildLogWriter([TLoggerProFileAppender.Create(10, 5)]);

    end.
    #)

    Add this unit to your project, then when you need to use the logger, include
    the unit and call one of the followings:
    @unorderedlist(
    @item(Log.Debug('This is a debug message', 'tag1'))
    @item(Log.Info('This is an information message', 'tag1'))
    @item(Log.Warn('This is a warning message', 'tag1'))
    @item(Log.Error('This is an error message', 'tag1'))
	@item(Log.Fatal('This is a fatal message', 'tag1'))	
    )
  }


  TLogItemRenderer = class abstract(TInterfacedObject, ILogItemRenderer)
  protected
    procedure Setup; virtual;
    procedure TearDown; virtual;
    function RenderLogItem(const aLogItem: TLogItem): String; virtual;abstract;
  public
    class function GetDefaultLogItemRenderer: ILogItemRenderer;
  end;
  TLogItemRendererClass = class of TLogItemRenderer;


function GetDefaultFormatSettings: TFormatSettings;
function StringToLogType(const aLogType: string): TLogType;
function BuildLogWriter(aAppenders: array of ILogAppender; aEventsHandlers: TLoggerProEventsHandler = nil;
  aLogLevel: TLogType = TLogType.Debug): ILogWriter; overload;
function BuildLogWriter(aAppenders: array of ILogAppender; aEventsHandlers: TLoggerProEventsHandler;
  aLogLevels: TArray<TLogType>): ILogWriter; overload;
function LogLayoutByPlaceHoldersToLogLayoutByIndexes(const LogLayoutByPlaceHolders: String; const UseZeroBasedIncrementalIndexes: Boolean): String;

implementation

uses
  System.Types,
  LoggerPro.FileAppender,
  System.SyncObjs,
  System.DateUtils,
  System.IOUtils,
  LoggerPro.Renderers;

function GetDefaultFormatSettings: TFormatSettings;
begin
  Result.DateSeparator := '-';
  Result.TimeSeparator := ':';
  Result.DecimalSeparator := '.';
  Result.ShortDateFormat := 'YYYY-MM-DD HH:NN:SS:ZZZ';
  Result.ShortTimeFormat := 'HH:NN:SS';
end;

function LogLayoutByPlaceHoldersToLogLayoutByIndexes(const LogLayoutByPlaceHolders: String; const UseZeroBasedIncrementalIndexes: Boolean): String;
var
  PlaceHolders, PlaceHolderWidthsAndPaddings: TArray<string>;
  I: Integer;
  lIdx: Integer;
begin
  if LogLayoutByPlaceHolders.Contains('%s') or LogLayoutByPlaceHolders.Contains('%d') then
  begin
    Exit(LogLayoutByPlaceHolders); //there aren't placeholders
  end;

  // Format specifiers have the following form:
  // "%" [index ":"] ["-"] [width] ["." proc] type

  //Format params by index are:
  // 0: timestamp
  // 1: threadid
  // 2: loglevel
  // 3: message
  // 4: tag

  SetLength(PlaceHolders, 5);
  PlaceHolders[0] := 'timestamp';
  PlaceHolders[1] := 'threadid';
  PlaceHolders[2] := 'loglevel';
  PlaceHolders[3] := 'message';
  PlaceHolders[4] := 'tag';

  //DEFAULT_LOG_FORMAT = '%0:s [TID %1:-8d][%2:-10s] %3:s [%4:s]';

  SetLength(PlaceHolderWidthsAndPaddings, Length(PlaceHolders));
  PlaceHolderWidthsAndPaddings[0] := '';
  PlaceHolderWidthsAndPaddings[1] := '8';
  PlaceHolderWidthsAndPaddings[2] := '-7';
  PlaceHolderWidthsAndPaddings[3] := '';
  PlaceHolderWidthsAndPaddings[4] := '';

  Result := LogLayoutByPlaceHolders;


  if UseZeroBasedIncrementalIndexes then
  begin
    lIdx := 0;
    for I := 0 to High(PlaceHolders) do
    begin
      if Result.Contains('{' + PlaceHolders[I] + '}') then
      begin
        Result := Result.Replace(
          '{' + PlaceHolders[I] + '}',
          '%' + IntToStr(lIdx) + ':' + PlaceHolderWidthsAndPaddings[I] + 's');
        Inc(lIdx);
      end;
    end;
  end
  else
  begin
    for I := 0 to High(PlaceHolders) do
    begin
      Result := Result.Replace(
        '{' + PlaceHolders[I] + '}',
        '%' + IntToStr(I) + ':' + PlaceHolderWidthsAndPaddings[I] + 's');
    end;
  end;
end;

function StringToLogType(const aLogType: string): TLogType;
var
  lLogType: string;
begin
  lLogType := LowerCase(Trim(aLogType));
  if lLogType = 'debug' then
    Exit(TLogType.Debug);
  if lLogType = 'info' then
    Exit(TLogType.Info);
  if lLogType = 'warning' then
    Exit(TLogType.Warning);
  if lLogType = 'error' then
    Exit(TLogType.Error);
  if lLogType = 'fatal' then
    Exit(TLogType.Fatal);
  raise ELoggerPro.CreateFmt('Invalid LogType: ', [aLogType]);
end;

function BuildLogWriter(aAppenders: array of ILogAppender; aEventsHandlers: TLoggerProEventsHandler; aLogLevel: TLogType): ILogWriter;
var
  lLogLevelsArray: TArray<TLogType>;
  I: Integer;
begin
  SetLength(lLogLevelsArray, length(aAppenders));
  for I := 0 to Length(lLogLevelsArray) - 1 do
  begin
    lLogLevelsArray[I] := aLogLevel;
  end;
  Result := BuildLogWriter(aAppenders, aEventsHandlers, lLogLevelsArray);
end;

function BuildLogWriter(aAppenders: array of ILogAppender; aEventsHandlers: TLoggerProEventsHandler; aLogLevels: TArray<TLogType>): ILogWriter;
var
  lLogAppenders: TLogAppenderList;
  lLowestLogLevel: TLogType;
  I: Integer;
begin
  lLowestLogLevel := TLogType.Fatal;
  if Length(aAppenders) <> Length(aLogLevels) then
  begin
    raise ELoggerPro.Create('LogLevels.Count <> Appenders.Count');
  end;
  lLogAppenders := TLogAppenderList.Create;
  for I := 0 to Length(aAppenders) - 1 do
  begin
    lLogAppenders.Add(aAppenders[I]);
    aAppenders[I].SetLogLevel(aLogLevels[I]);
    if aLogLevels[I] < lLowestLogLevel then
    begin
      lLowestLogLevel := aLogLevels[I];
    end;
  end;
  Result := TLogWriter.Create(lLogAppenders, lLowestLogLevel);
  TLogWriter(Result).Initialize(aEventsHandlers);
end;


{ TLogger.TCustomLogWriter }

function TCustomLogWriter.AppendersCount: Integer;
begin
  Result := Self.FLogAppenders.Count;
end;

constructor TCustomLogWriter.Create(const aLogAppenders: TLogAppenderList; const aLogLevel: TLogType = TLogType.Debug);
begin
  inherited Create;
  FEnabled := True;
  FFreeAllowed := False;
  FLogAppenders := aLogAppenders;
  FLogLevel := aLogLevel;
end;

constructor TCustomLogWriter.Create(const aLogLevel: TLogType = TLogType.Debug);
begin
  Create(TLogAppenderList.Create, aLogLevel);
end;

destructor TCustomLogWriter.Destroy;
begin
  FLoggerThread.Terminate;
  FLoggerThread.WaitFor;
  FLoggerThread.Free;
  FLogAppenders.Free;

  inherited Destroy;
end;

function TCustomLogWriter.GetAppenders(const aIndex: Integer): ILogAppender;
begin
  Result := Self.FLogAppenders[aIndex];
end;

procedure TCustomLogWriter.AddAppender(const aAppender: ILogAppender);
begin
  Self.FLogAppenders.Add(aAppender);
  if Assigned(Self.FLoggerThread.FAppendersDecorators) then
   Self.FLoggerThread.FAppendersDecorators.Add(TLoggerThread.TAppenderAdapter.Create(aAppender));
end;

procedure TCustomLogWriter.DelAppender(const aAppender: ILogAppender);
var
  i: Integer;
begin
  i := Self.FLoggerThread.FAppenders.IndexOf(aAppender);
  if i >= 0 then
    Self.FLoggerThread.FAppenders.Delete(i);

  i := Self.FLogAppenders.IndexOf(aAppender);
  if i >= 0 then
    Self.FLogAppenders.Delete(i);

  if Assigned(Self.FLoggerThread.FAppendersDecorators) then
    for i := Self.FLoggerThread.FAppendersDecorators.Count - 1 downto 0 do
      if Self.FLoggerThread.FAppendersDecorators[i].FLogAppender = aAppender then
        Self.FLoggerThread.FAppendersDecorators.Delete(i);
end;

function TCustomLogWriter.GetAppendersClassNames: TArray<string>;
var
  I: Cardinal;
begin
  TMonitor.Enter(FLogAppenders);
  try
    SetLength(Result, FLogAppenders.Count);
    for I := 0 to FLogAppenders.Count - 1 do
    begin
      Result[I] := TObject(FLogAppenders[I]).ClassName;
    end;
  finally
    TMonitor.Exit(FLogAppenders);
  end;
end;

procedure TCustomLogWriter.Initialize(const aEventsHandler: TLoggerProEventsHandler);
begin
  FLoggerThread := TLoggerThread.Create(FLogAppenders);

  FLoggerThread.EventsHandlers := aEventsHandler;
  FLoggerThread.Start;
end;

procedure TCustomLogWriter.Log(const aType: TLogType; const aMessage, aTag: string);
var
  lLogItem: TLogItem;
begin
  if FEnabled and (aType >= FLogLevel) then
  begin
    lLogItem := TLogItem.Create(aType, aMessage, aTag);
    try
      if not FLoggerThread.LogWriterQueue.Enqueue(lLogItem) then
      begin
        raise ELoggerPro.Create
          ('Main logs queue is full. Hints: Are there appenders? Are these appenders fast enough considering the log item production?');
      end;
    except
      FreeAndNil(lLogItem);
      raise;
    end;
  end;
end;

{ TLogger.TLogWriter }

procedure TLogWriter.Debug(const aMessage, aTag: string);
begin
  Log(TLogType.Debug, aMessage, aTag);
end;

procedure TLogWriter.Debug(const aMessage: string; const aParams: array of TVarRec; const aTag: string);
begin
  Log(TLogType.Debug, aMessage, aParams, aTag);
end;

procedure TLogWriter.Disable;
begin
  fEnabled := False;
end;

procedure TLogWriter.Error(const aMessage, aTag: string);
begin
  Log(TLogType.Error, aMessage, aTag);
end;

procedure TLogWriter.Enable;
begin
  fEnabled := True;
end;

procedure TLogWriter.Error(const aMessage: string; const aParams: array of TVarRec; const aTag: string);
begin
  Log(TLogType.Error, aMessage, aParams, aTag);
end;

procedure TLogWriter.Fatal(const aMessage, aTag: string);
begin
  Log(TLogType.Fatal, aMessage, aTag);
end;

procedure TLogWriter.Fatal(const aMessage: string;
  const aParams: array of TVarRec; const aTag: string);
begin
  Log(TLogType.Fatal, aMessage, aParams, aTag);
end;

procedure TLogWriter.Info(const aMessage, aTag: string);
begin
  Log(TLogType.Info, aMessage, aTag);
end;

procedure TLogWriter.Info(const aMessage: string; const aParams: array of TVarRec; const aTag: string);
begin
  Log(TLogType.Info, aMessage, aParams, aTag);
end;

procedure TLogWriter.Log(const aType: TLogType; const aMessage: string; const aParams: array of const; const aTag: string);
begin
  Log(aType, Format(aMessage, aParams), aTag);
end;

procedure TLogWriter.Warn(const aMessage, aTag: string);
begin
  Log(TLogType.Warning, aMessage, aTag);
end;

procedure TLogWriter.Warn(const aMessage: string; const aParams: array of TVarRec; const aTag: string);
begin
  Log(TLogType.Warning, aMessage, aParams, aTag);
end;

{ TLogger.TLogItem }

function TLogItem.Clone: TLogItem;
begin
  Result := TLogItem.Create(FType, FMessage, FTag, FTimeStamp, FThreadID);
end;

constructor TLogItem.Create(const aType: TLogType; const aMessage, aTag: string);
begin
  Create(aType, aMessage, aTag, now, TThread.CurrentThread.ThreadID);
end;

{ TLogger.TLoggerThread }

constructor TLoggerThread.Create(aAppenders: TLogAppenderList);
begin
  FQueue := TThreadSafeQueue<TLogItem>.Create(DefaultLoggerProMainQueueSize, 500);
  FAppenders := aAppenders;
  inherited Create(true);
  FreeOnTerminate := False;
end;

destructor TLoggerThread.Destroy;
begin
  FQueue.Free;
  inherited;
end;

procedure TLoggerThread.DoOnAppenderError(const FailAppenderClassName: string; const aFailedLogItem: TLogItem;
  const aReason: TLogErrorReason; var aAction: TLogErrorAction);
begin
  if Assigned(FEventsHandlers) and (Assigned(FEventsHandlers.OnAppenderError)) then
  begin
    FEventsHandlers.OnAppenderError(FailAppenderClassName, aFailedLogItem, aReason, aAction);
  end;
end;

procedure TLoggerThread.DoTerminate;
begin

  inherited;
end;

procedure TLoggerThread.Execute;
var
  lQSize: UInt64;
  lLogItem: TLogItem;
  I: Integer;
  lAction: TLogErrorAction;
  lWaitResult: TWaitResult;
begin
  FAppendersDecorators := BuildAppenderAdapters;
  try
    while True do
    begin
      lWaitResult := FQueue.Dequeue(lQSize, lLogItem);
      case lWaitResult of
        wrSignaled:
          begin
            if lLogItem <> nil then
            begin
              try
                for I := 0 to FAppendersDecorators.Count - 1 do
                begin
                  if lLogItem.LogType >= FAppendersDecorators[I].GetLogLevel then
                  begin
                    if not FAppendersDecorators[I].EnqueueLog(lLogItem) then
                    begin
                      lAction := TLogErrorAction.SkipNewest; // default
                      DoOnAppenderError(TObject(FAppendersDecorators[I].FLogAppender).ClassName, lLogItem,
                        TLogErrorReason.QueueFull, lAction);
                      case lAction of
                        TLogErrorAction.SkipNewest:
                          begin
                            // just skip the new message
                          end;
                        TLogErrorAction.DiscardOlder:
                          begin
                            // just remove the oldest log message
                            FAppendersDecorators[I].Queue.Dequeue.Free;
                          end;
                      end;
                    end;
                  end;
                end;
              finally
                lLogItem.Free;
              end;
            end;
          end;
        wrTimeout, wrAbandoned, wrError:
          begin
            if Terminated then
              Break;
          end;
        wrIOCompletion:
          begin
            raise ELoggerPro.Create('Unhandled WaitResult: wrIOCompletition');
          end;
      end;

    end;
  finally
    FAppendersDecorators.Free;
  end;
end;

procedure TLoggerThread.SetEventsHandlers(const Value: TLoggerProEventsHandler);
begin
  FEventsHandlers := Value;
end;

function TLoggerThread.BuildAppenderAdapters: TAppenderAdapterList;
var
  I: Integer;
begin
  Result := TAppenderAdapterList.Create;
  try
    for I := 0 to FAppenders.Count - 1 do
    begin
      Result.Add(TAppenderAdapter.Create(FAppenders[I]));
    end;
  except
    Result.Free;
    raise;
  end;
end;

constructor TLogItem.Create(const aType: TLogType; const aMessage, aTag: string; const aTimeStamp: TDateTime; const aThreadID: TThreadID);
begin
  inherited Create;
  FType := aType;
  FMessage := aMessage;
  FTag := aTag;
  FTimeStamp := aTimeStamp;
  FThreadID := aThreadID;
end;

function TLogItem.GetLogTypeAsString: string;
begin
  case FType of
    TLogType.Debug:
      Exit('DEBUG');
    TLogType.Info:
      Exit('INFO');
    TLogType.Warning:
      Exit('WARNING');
    TLogType.Error:
      Exit('ERROR');
    TLogType.Fatal:
      Exit('FATAL');
  else
    raise ELoggerPro.Create('Invalid LogType');
  end;
end;

{ TLoggerThread.TAppenderDecorator }

constructor TLoggerThread.TAppenderAdapter.Create(aAppender: ILogAppender);
begin
  inherited Create;
  FFailsCount := 0;
  FLogAppender := aAppender;
  FAppenderQueue := TAppenderQueue.Create(DefaultLoggerProAppenderQueueSize, 10);
  FAppenderThread := TAppenderThread.Create(FLogAppender, FAppenderQueue);
end;

destructor TLoggerThread.TAppenderAdapter.Destroy;
begin
  FAppenderQueue.DoShutDown;
  FAppenderThread.Terminate;
  FAppenderThread.Free;
  FAppenderQueue.Free;
  inherited;
end;

function TLoggerThread.TAppenderAdapter.GetLogLevel: TLogType;
begin
  Result := FLogAppender.GetLogLevel;
end;

function TLoggerThread.TAppenderAdapter.EnqueueLog(const aLogItem: TLogItem): Boolean;
var
  lLogItem: TLogItem;
begin
  lLogItem := aLogItem.Clone;
  Result := FAppenderQueue.Enqueue(lLogItem); // = TWaitResult.wrSignaled;
  if not Result then
  begin
    lLogItem.Free;
    FFailsCount := FFailsCount + 1
  end
  else
    FFailsCount := 0;
end;

{ TLoggerProAppenderBase }

constructor TLoggerProAppenderBase.Create(aLogItemRenderer: ILogItemRenderer);
begin
  inherited Create;
  Self.FLogLevel := TLogType.Debug;
  if Assigned(aLogItemRenderer) then
  begin
    Self.FLogItemRenderer := aLogItemRenderer;
  end
  else
  begin
    Self.FLogItemRenderer := GetDefaultLogItemRenderer;
  end;
  Self.FOnLogRow := nil;
end;

constructor TLoggerProAppenderBase.Create;
begin
  Create(nil);
end;

function TLoggerProAppenderBase.FormatLog(const ALogItem: TLogItem): string;
begin
  if Assigned(FOnLogRow) then
  begin
    FOnLogRow(ALogItem, Result);
  end
  else
  begin
    Result := FLogItemRenderer.RenderLogItem(ALogItem);
  end;
end;

function TLoggerProAppenderBase.GetLastErrorTimeStamp: TDateTime;
begin
  Result := FLastErrorTimeStamp;
end;

function TLoggerProAppenderBase.GetLogLevel: TLogType;
begin
  Result := FLogLevel;
end;

procedure TLoggerProAppenderBase.SetLastErrorTimeStamp(const Value: TDateTime);
begin
  FLastErrorTimeStamp := Value;
end;

procedure TLoggerProAppenderBase.SetLogLevel(const Value: TLogType);
begin
  FLogLevel := Value;
end;

procedure TLoggerProAppenderBase.Setup;
begin
  FFormatSettings := GetDefaultFormatSettings;
  FLogItemRenderer.Setup;
end;

procedure TLoggerProAppenderBase.TearDown;
begin
  FLogItemRenderer.TearDown;
end;

procedure TLoggerProAppenderBase.TryToRestart(var Restarted: Boolean);
begin
  Restarted := False;
  // do nothing "smart" here... descendant must implement specific "restart" strategies
end;

{ TAppenderThread }

constructor TAppenderThread.Create(aLogAppender: ILogAppender; aAppenderQueue: TAppenderQueue);
begin
  FLogAppender := aLogAppender;
  FAppenderQueue := aAppenderQueue;
  inherited Create(False);
end;

procedure TAppenderThread.Execute;
var
  lLogItem: TLogItem;
  lRestarted: Boolean;
  lStatus: TAppenderStatus;
  lSetupFailCount: Integer;
begin
  lSetupFailCount := 0;
  lStatus := TAppenderStatus.BeforeSetup;
  try
    { the appender tries to log all the messages before terminate... }
    //dt
    while (not Terminated) or (FAppenderQueue.QueueSize > 0) do
    begin
      { ...but if the thread should be terminated, and the appender is failing,
        its messages will be lost }
      if Terminated and (lStatus = TAppenderStatus.WaitAfterFail) then
        Break;

      try
        { this state machine handles the status of the appender }
        case lStatus of
          TAppenderStatus.BeforeTearDown:
            begin
              Break;
            end;

          TAppenderStatus.BeforeSetup:
            begin
              try
                FLogAppender.Setup;
                lStatus := TAppenderStatus.Running;
              except
                if lSetupFailCount = 10 then
                begin
                  lStatus := TAppenderStatus.WaitAfterFail;
                end
                else
                begin
                  Inc(lSetupFailCount);
                  Sleep(1000); // wait before next setup call
                end;
              end;
            end;

          TAppenderStatus.ToRestart:
            begin
              try
                lRestarted := False;
                FLogAppender.TryToRestart(lRestarted);
                if lRestarted then
                begin
                  lStatus := TAppenderStatus.Running;
                  FLogAppender.LastErrorTimeStamp := 0;
                end
                else
                begin
                  lRestarted := False;
                  FLogAppender.LastErrorTimeStamp := now;
                  lStatus := TAppenderStatus.WaitAfterFail;
                end;
              except
                lRestarted := False;
              end;
              Failing := not lRestarted;
            end;

          TAppenderStatus.WaitAfterFail:
            begin
              Sleep(500);
              if SecondsBetween(now, FLogAppender.LastErrorTimeStamp) >= 5 then
                lStatus := TAppenderStatus.ToRestart;
            end;

          TAppenderStatus.Running:
            begin
              if FAppenderQueue.Dequeue(lLogItem) = TWaitResult.wrSignaled then
              begin
                if lLogItem <> nil then
                begin
                  try
                    try
                      FLogAppender.WriteLog(lLogItem);
                    except
                      Failing := true;
                      FLogAppender.LastErrorTimeStamp := now;
                      lStatus := TAppenderStatus.WaitAfterFail;
                      Continue;
                    end;
                  finally
                    lLogItem.Free;
                  end;
                end;
              end;
            end;
        end;
      except
        // something wrong... but we cannot stop the thread. Let's retry.
      end;
    end;
  finally
    FLogAppender.TearDown;
  end;
end;

procedure TAppenderThread.SetFailing(const Value: Boolean);
begin
  FFailing := Value;
end;

{ TLoggerThread.TAppenderAdaptersList }

constructor TLoggerThread.TAppenderAdapterList.Create;
begin
  inherited Create(true);
end;

{ TLoggerProInterfacedObject }

function TLoggerProInterfacedObject._AddRef: Integer;
begin
  Result := inherited;
end;

function TLoggerProInterfacedObject._Release: Integer;
begin
  Result := inherited;
end;


{ TLogItemRenderer }

class function TLogItemRenderer.GetDefaultLogItemRenderer: ILogItemRenderer;
begin
  Result := LoggerPro.Renderers.GetDefaultLogItemRenderer;
end;

procedure TLogItemRenderer.Setup;
begin
  // do nothing
end;

procedure TLogItemRenderer.TearDown;
begin
  // do nothing
end;

end.

