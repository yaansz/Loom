unit Loom.Container.Registry;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  Loom.Attributes,
  Loom.Container.DataTypes;

type
  TComponentRegistration = record
    Factory               : TFunc<TObject>;
    Scope                 : TScope;
    UseAutowire           : Boolean;
    ImplementedInterfaces : TArray<TGUID>;
    Qualifiers            : TArray<QualifierAttribute>;
  end;

  TContainerRegistry = class
  private
    FClassRegistry     : TDictionary<TClass, TComponentRegistration>;
    FInterfaceRegistry : TDictionary<string, TList<TClass>>;
    FContext           : TRttiContext;

    procedure RegisterImplementedInterfaces(AClass: TClass; ImplementedInterfaces: TArray<TGUID>);
    function ClassImplementsInterface(AClass: TClass; const IID: TGUID): Boolean;
    function GetQualifiers(AClass : TClass) : TArray<QualifierAttribute>;

    procedure AutoRegisterType(AType: TRttiType);
  public
    constructor Create;
    destructor Destroy; override;

    function CreateKey(const IID: TGUID): string;

    procedure RegisterType(AClass: TClass; AFactory: TFunc<TObject>; Scope: TScope);
    procedure RegisterComponent(AClass: TClass; Scope: TScope);
    procedure RegisterInterface(const IID: TGUID; AClass: TClass; Scope: TScope);

    procedure AutoRegister(const UnitPattern: string);

    property ClassRegistry: TDictionary<TClass, TComponentRegistration> read FClassRegistry;
    property InterfaceRegistry: TDictionary<string, TList<TClass>> read FInterfaceRegistry;
  end;

implementation

uses
  System.Masks;

{ TContainerRegistry }

constructor TContainerRegistry.Create;
begin
  FClassRegistry     := TDictionary<TClass, TComponentRegistration>.Create;
  FInterfaceRegistry := TDictionary<string, TList<TClass>>.Create;
  FContext           := TRttiContext.Create;
end;

destructor TContainerRegistry.Destroy;
begin
  FInterfaceRegistry.Free;
  FClassRegistry.Free;
  FContext.Free;
  inherited;
end;

function TContainerRegistry.ClassImplementsInterface(AClass: TClass; const IID: TGUID): Boolean;
begin
  Result := AClass.GetInterfaceEntry(IID) <> nil;
end;

function TContainerRegistry.CreateKey(const IID: TGUID): string;
begin
  Result := GUIDToString(IID);
end;

procedure TContainerRegistry.RegisterType(AClass: TClass;
  AFactory: TFunc<TObject>; Scope: TScope);
var
  Reg: TComponentRegistration;
begin
  if not Assigned(AFactory) then
    raise EArgumentNilException.Create('Factory should not be nil');

  Reg.Factory     := AFactory;
  Reg.Scope       := Scope;
  Reg.UseAutowire := False;
  SetLength(Reg.ImplementedInterfaces, 0);
  FClassRegistry.AddOrSetValue(AClass, Reg);
end;

function TContainerRegistry.GetQualifiers(AClass : TClass) : TArray<QualifierAttribute>;
begin
  Result := [];

  var RttiType := FContext.GetType(AClass);

  for var Attr in RttiType.GetAttributes do
  begin
    if Attr is QualifierAttribute then
    begin
      SetLength(Result, Length(Result) + 1);
      Result[High(Result)] := QualifierAttribute(Attr);
    end;
  end;
end;

procedure TContainerRegistry.RegisterComponent(AClass: TClass; Scope: TScope);
var
  Reg         : TComponentRegistration;
  RttiType    : TRttiType;
  Attr        : TCustomAttribute;
  Implemented : TArray<TGUID>;
  Count       : Integer;
begin
  RttiType := FContext.GetType(AClass);
  SetLength(Implemented, 0);
  Count := 0;

  for Attr in RttiType.GetAttributes do
  begin
    if Attr is ImplementsAttribute then
    begin
      // Validate interface implementation
      if not ClassImplementsInterface(AClass, ImplementsAttribute(Attr).InterfaceGUID) then
        raise ENotImplemented.CreateFmt(
          'Class %s does not implement interface %s',
          [AClass.ClassName, GUIDToString(ImplementsAttribute(Attr).InterfaceGUID)]
        );

      Inc(Count);
      SetLength(Implemented, Count);
      Implemented[Count - 1] := ImplementsAttribute(Attr).InterfaceGUID;
    end;
  end;

  Reg.Factory               := nil;
  Reg.Scope                 := Scope;
  Reg.UseAutowire           := True;
  Reg.ImplementedInterfaces := Implemented;
  Reg.Qualifiers            := GetQualifiers(AClass);
  FClassRegistry.AddOrSetValue(AClass, Reg);

  RegisterImplementedInterfaces(AClass, Implemented);
end;

procedure TContainerRegistry.RegisterInterface(const IID: TGUID; AClass: TClass; Scope: TScope);
begin
  // Validate interface implementation
  if not ClassImplementsInterface(AClass, IID) then
    raise ENotImplemented.CreateFmt(
      'Class %s does not implement interface %s',
      [AClass.ClassName, GUIDToString(IID)]
    );

  if not FClassRegistry.ContainsKey(AClass) then
    RegisterComponent(AClass, Scope);

  var Implementations: TList<TClass>;

  if not FInterfaceRegistry.TryGetValue(IID.ToString, Implementations) then
  begin
    Implementations := TList<TClass>.Create;
    FInterfaceRegistry.Add(IID.ToString, Implementations);
  end;

  // Add if not exists
  if not Implementations.Contains(AClass) then
    Implementations.Add(AClass);
end;

procedure TContainerRegistry.RegisterImplementedInterfaces(AClass: TClass; ImplementedInterfaces: TArray<TGUID>);
var
  IID: TGUID;
begin
  for IID in ImplementedInterfaces do
    RegisterInterface(IID, AClass, Singleton);
end;

procedure TContainerRegistry.AutoRegisterType(AType: TRttiType);
var
  Attr       : TCustomAttribute;
  Cls        : TClass;
  ScopeValue : TScope;
begin
  if not (AType is TRttiInstanceType) then Exit;
  Cls := TRttiInstanceType(AType).MetaclassType;

  for Attr in AType.GetAttributes do
  begin
    if Attr is ServiceAttribute then
    begin
      ScopeValue := ServiceAttribute(Attr).Scope;
      RegisterComponent(Cls, ScopeValue);
    end
    else if Attr is ComponentAttribute then
    begin
      ScopeValue := ComponentAttribute(Attr).Scope;
      RegisterComponent(Cls, ScopeValue);
    end
    else if Attr is ImplementsAttribute then
    begin
      RegisterInterface(ImplementsAttribute(Attr).InterfaceGUID, Cls, TScope.Singleton);
    end;
  end;
end;

procedure TContainerRegistry.AutoRegister(const UnitPattern: string);
var
  AType    : TRttiType;
  UnitName : String;
begin
  for AType in FContext.GetTypes do
    begin
      if AType.IsInstance then
        begin
          UnitName := AType.AsInstance.MetaclassType.UnitName;

          if MatchesMask(UnitName, UnitPattern) then
            AutoRegisterType(AType);
        end;
    end;
end;

end.
