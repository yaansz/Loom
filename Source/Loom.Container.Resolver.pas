unit Loom.Container.Resolver;

interface

uses
  System.Rtti,
  System.TypInfo,
  System.SysUtils,
  System.Generics.Collections,
  Loom.Container.Registry;

type
  ECircularDependencyError = class(Exception);
  EContainerResolveException = class(Exception);

  TContainerResolver = class
  private
    FRegistry       : TContainerRegistry;
    FSingletons     : TDictionary<TClass, TObject>;
    FNonInterfaced  : TObjectDictionary<TClass, TObject>;
    FResolvingStack : TStack<TClass>;
    FResolvingSet   : TDictionary<TClass, Boolean>;
    FContext        : TRttiContext;

    function  CreateInstanceWithAutowiring(AClass: TClass): TObject;
    function  ResolveConstructorParameters(AClass: TClass; ConstructorMethod: TRttiMethod): TArray<TObject>;
    procedure InjectProperties(Instance: TObject);
    procedure CheckCircularDependency(AClass: TClass);
  public
    constructor Create(Registry: TContainerRegistry);
    destructor Destroy; override;

    function Resolve(AClass: TClass): TObject;
    function ResolveInterface(const IID: TGUID; const Name: string = ''): IInterface;
  end;

implementation

uses
  Loom.Attributes,
  Loom.Container.DataTypes;

{ TContainerResolver }

constructor TContainerResolver.Create(Registry: TContainerRegistry);
begin
  FRegistry       := Registry;
  FContext        := TRttiContext.Create;
  FSingletons     := TDictionary<TClass, TObject>.Create;
  FResolvingStack := TStack<TClass>.Create;
  FResolvingSet   := TDictionary<TClass, Boolean>.Create;
  FNonInterfaced  := TObjectDictionary<TClass, TObject>.Create([doOwnsValues]);
end;

destructor TContainerResolver.Destroy;
begin
  FResolvingSet.Free;
  FResolvingStack.Free;
  FSingletons.Free;
  FNonInterfaced.Free;
  FContext.Free;
  inherited;
end;

procedure TContainerResolver.CheckCircularDependency(AClass: TClass);
begin
  if FResolvingSet.ContainsKey(AClass) then
    raise ECircularDependencyError.CreateFmt('Circular dependency detected for %s', [AClass.ClassName]);
end;

function TContainerResolver.Resolve(AClass: TClass): TObject;
var
  Reg      : TComponentRegistration;
  Instance : TObject;
begin
  CheckCircularDependency(AClass);
  FResolvingStack.Push(AClass);
  FResolvingSet.Add(AClass, True);
  try
    if FSingletons.TryGetValue(AClass, Result) then
      Exit;

    if not FRegistry.ClassRegistry.TryGetValue(AClass, Reg) then
      raise EContainerResolveException.CreateFmt('Type not registered: %s', [AClass.ClassName]);

    try
      if Reg.UseAutowire
        then Instance := CreateInstanceWithAutowiring(AClass)
        else Instance := Reg.Factory();

      InjectProperties(Instance);

      if Reg.Scope = TScope.Singleton then
        begin
          FSingletons.Add(AClass, Instance);

          if not (Instance is TInterfacedObject) then
            FNonInterfaced.Add(AClass, Instance);
        end;

      Result := Instance;
    except
      on E : ECircularDependencyError do
        raise;
      on E: Exception do
        raise EContainerResolveException.CreateFmt('Error resolving %s: %s', [AClass.ClassName, E.Message]);
    end;
  finally
    FResolvingSet.Remove(FResolvingStack.Pop);
  end;
end;

function TContainerResolver.ResolveInterface(const IID: TGUID; const Name: string = ''): IInterface;
var
  Key      : string;
  AClass   : TClass;
  Instance : TObject;
begin
  Key := FRegistry.CreateKey(IID, Name);

  if not FRegistry.InterfaceRegistry.TryGetValue(Key, AClass) then
    raise EContainerResolveException.CreateFmt('Interface not registered: %s [%s]',
      [GUIDToString(IID), Name]);

  Instance := Resolve(AClass);

  if not Supports(Instance, IID, Result) then
    raise EContainerResolveException.CreateFmt('Class %s does not implement interface %s',
      [AClass.ClassName, GUIDToString(IID)]);
end;

function TContainerResolver.CreateInstanceWithAutowiring(AClass: TClass): TObject;
var
  RttiType            : TRttiType;
  Constructors        : TArray<TRttiMethod>;
  Ctor                : TRttiMethod;
  SelectedConstructor : TRttiMethod;
  Params              : TArray<TObject>;
  ParamValues         : TArray<TValue>;
  I                   : Integer;
begin
  RttiType     := FContext.GetType(AClass);
  Constructors := RttiType.GetMethods;

  // Initialize to nil to satisfy compiler
  SelectedConstructor := nil;

  // First pass: Try to find a parameterized constructor we can satisfy
  for Ctor in Constructors do
  begin
    if Ctor.IsConstructor and (Length(Ctor.GetParameters) > 0) then
    begin
      // Test if we can resolve parameters
      Params := ResolveConstructorParameters(AClass, Ctor);
      SelectedConstructor := Ctor;
      Break; // Exit loop when we find a valid constructor
    end;
  end;

  // Second pass: If no parameterized constructor found, look for default
  if SelectedConstructor = nil then
  begin
    for Ctor in Constructors do
    begin
      if Ctor.IsConstructor and (Length(Ctor.GetParameters) = 0) then
      begin
        SelectedConstructor := Ctor;
        Break;
      end;
    end;
  end;

  // Validate we found a constructor
  if SelectedConstructor = nil then
    raise EContainerResolveException.CreateFmt('No suitable constructor found for %s', [AClass.ClassName]);

  // Handle parameterless constructor
  if Length(SelectedConstructor.GetParameters) = 0 then
  begin
    Result := SelectedConstructor.Invoke(AClass, []).AsObject;
  end
  else
  begin
    // Resolve parameters for parameterized constructor
    Params := ResolveConstructorParameters(AClass, SelectedConstructor);

    // Prepare parameter values
    SetLength(ParamValues, Length(Params));
    for I := 0 to High(Params) do
      ParamValues[I] := TValue.From<TObject>(Params[I]);

    // Invoke constructor
    Result := SelectedConstructor.Invoke(AClass, ParamValues).AsObject;
  end;

  if not Assigned(Result) then
    raise EContainerResolveException.CreateFmt('Constructor did not return a valid value for %s', [AClass.ClassName]);
end;

function TContainerResolver.ResolveConstructorParameters(AClass: TClass; ConstructorMethod: TRttiMethod): TArray<TObject>;
var
  Params           : TArray<TRttiParameter>;
  I                : Integer;
  ParamType        : TRttiType;
  InterfaceGUID    : TGUID;
  ImplementerClass : TClass;
begin
  Params := ConstructorMethod.GetParameters;
  SetLength(Result, Length(Params));

  for I := 0 to High(Params) do
  begin
    ParamType := Params[I].ParamType;

    if ParamType.IsInstance then
    begin
      // Class dependency
      Result[I] := Resolve(ParamType.AsInstance.MetaclassType);
    end
    else if (ParamType.TypeKind = tkInterface) and
            (ParamType is TRttiInterfaceType) then
    begin
      // Interface dependency
      InterfaceGUID := TRttiInterfaceType(ParamType).GUID;

      if not FRegistry.InterfaceRegistry.TryGetValue(FRegistry.CreateKey(InterfaceGUID, ''), ImplementerClass) then
        raise EContainerResolveException.CreateFmt('No implementation registered for interface %s',
          [GUIDToString(InterfaceGUID)]);

      Result[I] := Resolve(ImplementerClass);
    end
    else
    begin
      raise EContainerResolveException.CreateFmt('Unsupported parameter type in %s: %s',
        [AClass.ClassName, ParamType.ToString]);
    end;
  end;
end;

procedure TContainerResolver.InjectProperties(Instance: TObject);
var
  RttiType  : TRttiType;
  Prop      : TRttiProperty;
  PropValue : TObject;
  PropIntf  : IInterface;
  ValueIntf : TValue;
  Attr      : TCustomAttribute;
  Field     : TRttiField;
  Autowired : AutowiredAttribute;
begin
  RttiType := FContext.GetType(Instance.ClassType);

  for Field in RttiType.GetFields do
  begin
    Autowired := Field.GetAttribute<AutowiredAttribute>;

    if Assigned(Autowired) then
      begin
        if Field.FieldType.IsInstance then
          begin
            PropValue := Resolve(Field.FieldType.AsInstance.MetaclassType);
            Field.SetValue(Instance, TValue.From<TObject>(PropValue));
          end
        else if Field.FieldType.TypeKind = tkInterface then
          begin
            PropIntf := ResolveInterface(TRttiInterfaceType(Field.FieldType).GUID);
            TValue.Make(@PropIntf, Field.FieldType.Handle, ValueIntf);

            Field.SetValue(Instance, ValueIntf);
          end
        else
          raise EContainerResolveException.CreateFmt('Autowired property must be class type: %s.%s', [Instance.ClassName, Prop.Name]);
      end;
  end;

  for Prop in RttiType.GetProperties do
  begin
    for Attr in Prop.GetAttributes do
    begin
      if Attr is AutowiredAttribute then
      begin
        if Prop.PropertyType.IsInstance then
          begin
            PropValue := Resolve(Prop.PropertyType.AsInstance.MetaclassType);
            Prop.SetValue(Instance, TValue.From<TObject>(PropValue));
          end
        else if Prop.PropertyType.TypeKind = tkInterface then
          begin
            PropIntf := ResolveInterface(TRttiInterfaceType(Prop.PropertyType).GUID);
            TValue.Make(@PropIntf, Field.FieldType.Handle, ValueIntf);

            Prop.SetValue(Instance, ValueIntf);
          end
        else
          raise EContainerResolveException.CreateFmt('Autowired property must be class type: %s.%s', [Instance.ClassName, Prop.Name]);
      end;
    end;
  end;
end;


end.
