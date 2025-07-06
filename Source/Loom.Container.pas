unit Loom.Container;

interface

uses
  System.Rtti,
  System.TypInfo,
  System.SysUtils,
  System.Generics.Collections,
  Loom.Attributes,
  Loom.Container.Registry,
  Loom.Container.Resolver,
  Loom.Container.DataTypes;

type
  TScope = Loom.Container.DataTypes.TScope;

  LoomContainer = class
  private
    FRegistry: TContainerRegistry;
    FResolver: TContainerResolver;
  public
    constructor Create;
    destructor Destroy; override;

    // Class registration
    procedure RegisterType(AClass: TClass; AFactory: TFunc<TObject>; Scope: TScope = TScope.Singleton);
    procedure RegisterComponent(AClass: TClass; Scope: TScope = TScope.Singleton);

    // Interface registration
    procedure RegisterInterface(const IID: TGUID; AClass: TClass; Scope: TScope = TScope.Singleton; const Name: string = '');
    procedure RegisterInterfaceWithClass(const IID: TGUID; AClass: TClass; Scope: TScope = TScope.Singleton; const Name: string = '');

    // Resolution methods
    function Resolve<T: class>: T; overload;
    function Resolve(AClass: TClass): TObject; overload;
    function ResolveInterface(const IID: TGUID; const Name: string = ''): IInterface; overload;
    function ResolveInterface<T: IInterface>(const Name: string = ''): T; overload;

    // Auto Register
    procedure AutoRegister(const UnitPattern: string);

    class function  GetDefaultContainer: LoomContainer;
    class procedure SetDefaultContainer(Container: LoomContainer);
    class procedure ForceReferenceToClass(C: TClass);
  end;

var
  DefaultContainer: LoomContainer = nil;

implementation

uses
  System.Masks;

{ LoomContainer }

constructor LoomContainer.Create;
begin
  FRegistry := TContainerRegistry.Create;
  FResolver := TContainerResolver.Create(FRegistry);
end;

destructor LoomContainer.Destroy;
begin
  FResolver.Free;
  FRegistry.Free;
  inherited;
end;

procedure LoomContainer.RegisterType(AClass: TClass; AFactory: TFunc<TObject>; Scope: TScope);
begin
  FRegistry.RegisterType(AClass, AFactory, Scope);
end;

procedure LoomContainer.RegisterComponent(AClass: TClass; Scope: TScope);
begin
  FRegistry.RegisterComponent(AClass, Scope);
end;

procedure LoomContainer.RegisterInterface(const IID: TGUID; AClass: TClass;
  Scope: TScope; const Name: string);
begin
  FRegistry.RegisterInterface(IID, AClass, Scope, Name);
end;

procedure LoomContainer.RegisterInterfaceWithClass(const IID: TGUID; AClass: TClass; Scope: TScope; const Name: string);
begin
  FRegistry.RegisterInterface(IID, AClass, Scope, Name);
end;

function LoomContainer.Resolve(AClass: TClass): TObject;
begin
  Result := FResolver.Resolve(AClass);
end;

function LoomContainer.Resolve<T>: T;
begin
  Result := T(FResolver.Resolve(TClass(T)));
end;

function LoomContainer.ResolveInterface(const IID: TGUID; const Name: string): IInterface;
begin
  Result := FResolver.ResolveInterface(IID, Name);
end;

function LoomContainer.ResolveInterface<T>(const Name: string): T;
var
  IID        : TGUID;
  IntfResult : IInterface;
begin
  IID := GetTypeData(TypeInfo(T))^.Guid;
  IntfResult := FResolver.ResolveInterface(IID, Name);
  Supports(IntfResult, IID, Result);
end;

procedure LoomContainer.AutoRegister(const UnitPattern: string);
begin
  FRegistry.AutoRegister(UnitPattern);
end;

class function LoomContainer.GetDefaultContainer: LoomContainer;
begin
  if not Assigned(DefaultContainer) then
    DefaultContainer := LoomContainer.Create;
  Result := DefaultContainer;
end;

class procedure LoomContainer.SetDefaultContainer(Container: LoomContainer);
begin
  DefaultContainer := Container;
end;

class procedure LoomContainer.ForceReferenceToClass(C: TClass);
begin
  // We are forcing Delphi to link this class, don't need to do anything...
end;

initialization

finalization
  FreeAndNil(DefaultContainer);

end.
