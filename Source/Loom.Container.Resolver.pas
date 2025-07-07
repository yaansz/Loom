unit Loom.Container.Resolver;

interface

uses
  System.Rtti,
  System.TypInfo,
  System.SysUtils,
  System.Generics.Collections,
  Loom.Attributes,
  Loom.Container.Registry,
  Loom.Container.Injector;

type
  ECircularDependencyError = class(Exception);
  EContainerResolveException = class(Exception);

  TContainerResolver = class
  private
    FRegistry       : TContainerRegistry;
    FSingletons     : TDictionary<TClass, TObject>;
    FNonInterfaced  : TObjectDictionary<TClass, TObject>;
    FInterfaced     : TList<IInterface>;

    FResolvingStack : TStack<TClass>;
    FResolvingSet   : TDictionary<TClass, Boolean>;
    FContext        : TRttiContext;
    FInjector       : TPropertyInjector;

    function  CreateInstanceWithAutowiring(AClass: TClass): TObject;
    function  ResolveConstructorParameters(AClass: TClass; ConstructorMethod: TRttiMethod): TArray<TValue>;
    procedure InjectProperties(Instance: TObject);
    procedure CheckCircularDependency(AClass: TClass);

    function GetCandidates(Implementations : TList<TClass>; Qualifiers: TArray<QualifierAttribute>) : TArray<TClass>;
  public
    constructor Create(Registry: TContainerRegistry);
    destructor Destroy; override;

    function Resolve(AClass: TClass): TObject;
    function ResolveInterface(const IID: TGUID; Qualifiers: TArray<QualifierAttribute>): IInterface;
  end;

implementation

uses
  Loom.Container.Utils,
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
  FInterfaced     := TList<IInterface>.Create;
  FInjector       := TPropertyInjector.Create(Resolve, ResolveInterface, FContext);
end;

destructor TContainerResolver.Destroy;
begin
  FResolvingSet.Free;
  FResolvingStack.Free;
  FSingletons.Free;
  FNonInterfaced.Free;
  FInterfaced.Free;
  FInjector.Free;
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
  Intf     : IInterface;
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
            FNonInterfaced.Add(AClass, Instance)
          else if (Instance is TInterfacedObject) and Supports(Instance, IInterface, Intf) then
            FInterfaced.Add(Intf);
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

function TContainerResolver.ResolveInterface(const IID: TGUID; Qualifiers: TArray<QualifierAttribute>): IInterface;
var
  Key             : String;
  Implementations : TList<TClass>;
  Instance        : TObject;
begin
  Key := FRegistry.CreateKey(IID);

  if not FRegistry.InterfaceRegistry.TryGetValue(Key, Implementations) then
    raise EContainerResolveException.CreateFmt('Interface not registered: %s', [GUIDToString(IID)]);

  if Implementations.Count = 0 then
    raise EContainerResolveException.CreateFmt('No implementations for interface %s', [GUIDToString(IID)]);

  var Candidates := GetCandidates(Implementations, Qualifiers);

  if Length(Candidates) = 0 then
    raise EContainerResolveException.CreateFmt('No matching implementation for %s', [GUIDToString(IID)]);

  if Length(Candidates) > 1 then
    raise EContainerResolveException.CreateFmt('Multiple implementations for %s', [GUIDToString(IID)]);

  Instance := Resolve(Candidates[0]);

  if not Supports(Instance, IID, Result) then
    raise EContainerResolveException.CreateFmt('Class %s does not implement interface %s',
      [Instance.ClassName, GUIDToString(IID)]);
end;

function TContainerResolver.GetCandidates(Implementations: TList<TClass>; Qualifiers: TArray<QualifierAttribute>): TArray<TClass>;
var
  Reg : TComponentRegistration;
begin
  Result         := [];
  var Candidates := TList<TClass>.Create;

  try
    for var Candidate in Implementations do
      begin
        if not FRegistry.ClassRegistry.TryGetValue(Candidate, Reg) then
          Continue;

        var Matches := True;

        for var Req in Qualifiers do
        begin
          var Found := False;

          for var RegQual in Reg.Qualifiers do
          begin
            if RegQual.ClassType = Req.ClassType then
            begin
              Found := True;
              Break;
            end;
          end;

          if not Found then
          begin
            Matches := False;
            Break;
          end;
      end;

      if Matches then
        Candidates.Add(Candidate);
      end;

    Result := Candidates.ToArray;
  finally
    Candidates.Free;
  end;
end;

function TContainerResolver.CreateInstanceWithAutowiring(AClass: TClass): TObject;
var
  RttiType            : TRttiType;
  Constructors        : TArray<TRttiMethod>;
  Ctor                : TRttiMethod;
  SelectedConstructor : TRttiMethod;
  Params              : TArray<TValue>;
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

    // Invoke constructor
    Result := SelectedConstructor.Invoke(AClass, Params).AsObject;
  end;

  if not Assigned(Result) then
    raise EContainerResolveException.CreateFmt('Constructor did not return a valid value for %s', [AClass.ClassName]);
end;

function TContainerResolver.ResolveConstructorParameters(AClass: TClass;ConstructorMethod: TRttiMethod): TArray<TValue>;
var
  Params           : TArray<TRttiParameter>;
  I                : Integer;
  ParamType        : TRttiType;
  InterfaceGUID    : TGUID;
begin
  Params := ConstructorMethod.GetParameters;
  SetLength(Result, Length(Params));

  for I := 0 to High(Params) do
  begin
    ParamType := Params[I].ParamType;

    if ParamType.IsInstance then
    begin
      // Class dependency - resolve and store as object
      Result[I] := TValue.From<TObject>(Resolve(ParamType.AsInstance.MetaclassType));
    end
    else if (ParamType.TypeKind = tkInterface) and
            (ParamType is TRttiInterfaceType) then
    begin
      // Interface dependency - resolve and store as interface
      InterfaceGUID := TRttiInterfaceType(ParamType).GUID;
      var ParamIntf := ResolveInterface(InterfaceGUID, TLoomUtils.GetQualifiers(Params[I].GetAttributes));

      TValue.Make(@ParamIntf, ParamType.Handle, Result[I]);
    end
    else
    begin
      raise EContainerResolveException.CreateFmt(
        'Unsupported parameter type in %s: %s',
        [AClass.ClassName, ParamType.ToString]
      );
    end;
  end;
end;

procedure TContainerResolver.InjectProperties(Instance: TObject);
begin
  FInjector.Inject(Instance);
end;

end.
