unit Loom.Container.Registry;

interface

uses
  System.Rtti,
  System.SysUtils,
  System.Generics.Collections,
  Loom.Container.DataTypes;

type
  TComponentRegistration = record
    Factory: TFunc<TObject>;
    Scope: TScope;
    UseAutowire: Boolean;
    ImplementedInterfaces: TArray<TGUID>;
  end;

  TContainerRegistry = class
  private
    FClassRegistry     : TDictionary<TClass, TComponentRegistration>;
    FInterfaceRegistry : TDictionary<string, TClass>;
    FContext           : TRttiContext;

    procedure RegisterImplementedInterfaces(AClass: TClass; ImplementedInterfaces: TArray<TGUID>);
    function ClassImplementsInterface(AClass: TClass; const IID: TGUID): Boolean;

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
    property InterfaceRegistry: TDictionary<string, TClass> read FInterfaceRegistry;
  end;

implementation

uses
  System.Masks,
  Loom.Attributes;

{ TContainerRegistry }

constructor TContainerRegistry.Create;
begin
  FClassRegistry     := TDictionary<TClass, TComponentRegistration>.Create;
  FInterfaceRegistry := TDictionary<string, TClass>.Create;
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
var
  RttiType : TRttiType;
  IntfType : TRttiInterfaceType;
begin
  RttiType := FContext.GetType(AClass);

  // Check if the class directly implements the interface
  for IntfType in RttiType.AsInstance.GetImplementedInterfaces do
  begin
    if IntfType.GUID = IID then
      Exit(True);
  end;

  // Check if any ancestor implements the interface
  if RttiType.BaseType <> nil then
    Result := ClassImplementsInterface(RttiType.BaseType.AsInstance.MetaclassType, IID)
  else
    Result := False;
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

  Reg.Factory := nil;
  Reg.Scope := Scope;
  Reg.UseAutowire := True;
  Reg.ImplementedInterfaces := Implemented;
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

  FInterfaceRegistry.AddOrSetValue(CreateKey(IID), AClass);
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
