unit Loom.Attributes;

interface

uses
  Loom.Container.DataTypes;

type
  QualifierAttribute = class(TCustomAttribute)
  end;

  ComponentAttribute = class(TCustomAttribute)
  private
    FScope: TScope;
  public
    constructor Create(const Scope: TScope = TScope.Singleton);
    property Scope: TScope read FScope;
  end;

  ServiceAttribute = class(ComponentAttribute)
  public
    constructor Create(const Scope: TScope = TScope.Singleton);
  end;

  AutowiredAttribute = class(TCustomAttribute);

  ImplementsAttribute = class(TCustomAttribute)
  private
    FInterfaceGUID: TGUID;
  public
    constructor Create(const IID: TGUID);
    property InterfaceGUID: TGUID read FInterfaceGUID;
  end;

implementation

{ ComponentAttribute }

constructor ComponentAttribute.Create(const Scope: TScope);
begin
  inherited Create;
  FScope := Scope;
end;

{ ServiceAttribute }

constructor ServiceAttribute.Create(const Scope: TScope);
begin
  inherited Create(Scope);
end;

{ ImplementsAttribute }

constructor ImplementsAttribute.Create(const IID: TGUID);
begin
  inherited Create;
  FInterfaceGUID := IID;
end;

end.
