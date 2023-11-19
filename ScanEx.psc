ScriptName ScanEx Extends ScriptObject

Bool bResetMissionsQueued = False;
Bool bHandScanner = False;
Bool bSpaceShipEditor = False;
Int iPilotSeatIsNearID = 1000 Const;
ShipVendorScript ShipVendor = None;
String ShipVendorName = "";
String sStarfieldEsm = "Starfield.esm" Const;

Int KYWD_AnimFurnTerminal_Standing = 0x0025E8DE Const ;		;; KYWD
Keyword AnimFurnTerminal_Standing = None;
Int KYWD_Terminal_Swap_Keyword01 = 0x000B799F Const;		;; KYWD
Keyword Terminal_Swap_Keyword01 = None;
;;Int ACTI_TradeAuthorityVendorKiosk = 0x001150B3 Const;		;; ACTI
;;Form TradeAuthorityVendorKiosk = None;
Int AVIF_HandScannerTarget = 0x0022A2B6 Const ;				;; AVIF
ActorValue HandScannerTarget = None ;
Int ACTI_MissionBoardConsole_ALL = 0x001A6C49 ;				;; ACTI

;; Int QUST_MB_Parent = 0x00015300 Const;						;; QUST
MissionParentScript MB_Parent = None;
Int QUST_SQ_PlayerShip = 0x000174A2 Const;					;; QUST
SQ_PlayerShipScript SQ_PlayerShip = None;

Int GLOB_ShipBuilderAllowLargeModules = 0x00155F4A;			;; GLOB
Int GLOB_ShipBuilderTestModules = 0x00141C71;				;; GLOB

Int NPC_OutpostShipbuilderVendor = 0x0002F8FD;				;; NPC_
Int NPC_NeonStroudStore_KioskVendor = 0x00151488;			;; NPC_

;;Int MESG_OutpostShipbuilderMessage = 0x0002F8FE;			;; MESG
Int MESG_ShipbuilderActivatorMessage = 0x0002EE15;			;; MESG
      
Struct ShipVendorStruct
	Form ShipVendor = None;
	String Name = "";
EndStruct
ShipVendorStruct[] ShipVendors;

ObjectReference CurrentPlace = None;
SpaceShipReference CurrentShip = None;
Bool CurrentShipIsLanded = False;

;; ---- Common part -----

Function Tip(String v1, String v2 = "", String v3 = "", String v4 = "", String v5 = "", String v6 = "", String v7 = "", String v8 = "", String v9 = "", String v10 = "")
	Debug.Notification(v1 + v2 + v3 + v4 + v5 + v6 + v7 + v8 + v9 + v10);
EndFunction

Bool DebugBuild = False Const;
Function Dbg(String v1, String v2 = "", String v3 = "", String v4 = "", String v5 = "", String v6 = "", String v7 = "", String v8 = "", String v9 = "", String v10 = "")
	If DebugBuild == True
		Debug.Notification("DEBUG:\n" + v1 + v2 + v3 + v4 + v5 + v6 + v7 + v8 + v9 + v10);
	EndIf
EndFunction

Function DbgObj(ObjectReference obj_ref)
	If DebugBuild
		String ID = Utility.IntToHex((obj_ref as Form).GetFormID());
		Debug.ExecuteConsole(ID + ".ShowVars");
	EndIf
EndFunction

Form Function RC(Int FormID)
	Return Game.GetFormFromFile(FormID, sStarfieldEsm);
EndFunction

GlobalVariable Function GLOB(Int FormID)
	Return RC(FormID) as GlobalVariable;
EndFunction

Function InitScanEx()
	Tip("USE SCANEX EVERYWHERE!", "\n", "ЮЗE $ЦAИЭX ЭVEЯYФHEЯE!");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnPlayerScannedObject");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnLocationChange");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnEnterShipInterior");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnExitShipInterior");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnPlayerLoadGame");
	Self.RegisterForMenuOpenCloseEvent("MonocleMenu");

	SQ_PlayerShip = RC(QUST_SQ_PlayerShip) as SQ_PlayerShipScript;
	MB_Parent = GetFormProperty(RC(ACTI_MissionBoardConsole_ALL), "MB_Parent") as MissionParentScript;	
;;	MB_Parent = RC(QUST_MB_Parent) as MissionParentScript; ;;' don't do this
	HandScannerTarget = RC(AVIF_HandScannerTarget) as ActorValue;	

;;	Dbg(Game.GetPlayer().GetCurrentShipRef() as String, "\n", SQ_PlayerShip.PlayerShip.GetRef());	
	
	UpdateLocationChange();
EndFunction

Event OnInit()
	InitScanEx();
EndEvent

Event Actor.OnPlayerLoadGame()
	InitScanEx();
EndEvent

Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
	Dbg(asMenuName, " ", abOpening as String, ", state ", GetState());
	If asMenuName == "MonocleMenu" 
		ProcessMonocleMenu(abOpening);
	EndIf	
	If asMenuname == "SpaceshipEditorMenu"
		ProcessSpaceEditorMenu(abOpening);
	EndIf
EndEvent

Event Actor.OnPlayerScannedObject(Actor akSource, ObjectReference akScannedRef)
	If GetState() != "None"
		akScannedRef.SetScanned(False);	
		Return;
	EndIf
	If akSource != Game.GetPlayer()
		Return;
	EndIf
	Dbg("Scanned ", akScannedRef as String);
	If TerminalCondition(akScannedRef)
		TerminalScanned(akSource, akScannedRef);
	ElseIf PilotSeatCondition(akScannedRef)
		PilotSeatScanned(akSource, akScannedRef);
	EndIf
EndEvent

Function UpdateLocationChange()
	If IsInShip()
		InitShipVendor();
	Else
		InitTerminalsSearch();
	EndIf		
EndFunction

;;; -- take a look at first parameter --
Event Actor.OnLocationChange(Actor akSender, Location akOldLoc, Location akNewLoc)
	If akSender != Game.GetPlayer()
		Return;
	EndIf
	UpdateLocationChange();
EndEvent

;;; -- take a look at first parameter --
Event Actor.OnEnterShipInterior(Actor akSender, ObjectReference akShip)
	If akSender != Game.GetPlayer()
		Return;
	EndIf
	Self.RegisterForMenuOpenCloseEvent("SpaceshipEditorMenu") ; 
EndEvent

;;; -- take a look at first parameter --
Event Actor.OnExitShipInterior(Actor akSender, ObjectReference akShip)
	If akSender != Game.GetPlayer()
		Return;
	EndIf
	Self.UnRegisterForMenuOpenCloseEvent("SpaceshipEditorMenu") ;
EndEvent

Var Function GetFormProperty(Form _Form, String PropertyName)
	ObjectReference obj_ref = Game.GetPlayer().PlaceAtMe(_Form, 1, False, True, True, None, None, True);
	Var value = obj_ref.GetPropertyValue("MB_Parent");
	obj_ref.Delete();	
	Return value;
EndFunction

;; ---- Mission boards ------------

Function InitTerminalsSearch()
	Terminal_Swap_Keyword01 = RC(KYWD_Terminal_Swap_Keyword01) as Keyword;
	AnimFurnTerminal_Standing = RC(KYWD_AnimFurnTerminal_Standing) as Keyword;
;;	TradeAuthorityVendorKiosk = RC(ACTI_TradeAuthorityVendorKiosk);

	GoToState("ResetMissions_State");
	ResetMissions(True);
	GoToState("None");
	SearchAndReloadTerminals();
EndFunction

ObjectReference Function ReCreateObject(ObjectReference obj_ref)
	Float[] Coords = new Float[6];
	Coords[0] = obj_ref.X;
	Coords[1] = obj_ref.Y;
	Coords[2] = obj_ref.Z;
	Coords[3] = obj_ref.GetAngleX();
	Coords[4] = obj_ref.GetAngleY();
	Coords[5] = obj_ref.GetAngleZ();			
	ObjectReference new_obj_ref = Game.GetPlayer().PlaceAtMe(obj_ref.GetBaseObject(), 1, True, True, False, None, None, True);
	new_obj_ref.SetPosition(Coords[0], Coords[1], Coords[2]);
	new_obj_ref.SetAngle(Coords[3], Coords[4], Coords[5]);
	new_obj_ref.Enable(False);	
	obj_ref.Delete();
	obj_ref = new_obj_ref;
	Return obj_ref;
EndFunction

Guard SearchAndReloadTerminals_Guard
Function SearchAndReloadTerminals()
	Guard SearchAndReloadTerminals_Guard
	ObjectReference[] obj_refs = SearchForTerminals(20000.0);
;;	Int I = 0;
;;	While I < obj_refs.Length
;;		If (obj_refs[I].GetBaseObject() == TradeAuthorityVendorKiosk)	
;;			InitTerminal(ReCreateObject(obj_refs[I]));
;;			DbgObj(obj_refs[I]);
;;		EndIf
;;		I += 1;
;;	EndWhile
	If obj_refs.Length > 0
		Tip(obj_refs.Length as String, " TERMINALS FOUND", "\n", obj_refs.Length as String, " ЩЭЯMIИAЛ$ ЪOУИД");
	EndIf
	EndGuard
EndFunction

Bool Function TerminalCondition(ObjectReference akScannedRef)
	Return akScannedRef.HasKeyword(Terminal_Swap_Keyword01) || akScannedRef.HasKeyword(AnimFurnTerminal_Standing);  // || akScannedRef.GetBaseObject() == TradeAuthorityVendorKiosk;
EndFunction

Function TerminalScanned(Actor akSource, ObjectReference akScannedRef)	
	akScannedRef.SetScanned(False);	
	If GetState() == "ShowMissions_State"
		Return;
	EndIf
	If GetState() != "None"
		Tip("NO ACCESS TO TERMINAL", "\n", "C**A B***T DN1WE E****E");
		Return;
	EndIf
	GoToState("ShowMissions_State")
	ShowMissions(akScannedRef);
	GoToState("None");	
EndFunction

Function ProcessMonocleMenu(Bool abOpening)
	bHandScanner = abOpening;
	If !bHandScanner
		If bResetMissionsQueued && GetState() == "None"
			GoToState("ResetMissions_State");
			ResetMissions();
		EndIf
		GoToState("None");
		ResetPilotSeat();
	Else
		bResetMissionsQueued = False;
	EndIf
EndFunction

Function ShowMissions(ObjectReference akScannedRef)
EndFunction

State ShowMissions_State
	Function ShowMissions(ObjectReference akScannedRef)
		Tip("TERMINAL DETECTED", "\n", "ЩЭЯMIИAЛ ДETEKTЭД");		
		MB_Parent.UpdateMissions();
		Tip("TERMINAL HACKED", "\n", "ЩЭЯMIИAЛ ФАЦКЭД");		
		Game.ShowMissionBoardMenu(None, Utility.RandomInt(1, 6));
		bResetMissionsQueued = True;
	EndFunction
EndState

ObjectReference[] Function ConcatArrays(ObjectReference[] arr1, ObjectReference[] arr2)
	ObjectReference[] dst = new ObjectReference[0];
	Int I = 0;
	While I < arr1.Length
		If dst.Find(arr1[I], 0) < 0
			dst.Add(arr1[I], 1);
		EndIf
		I += 1;
	EndWhile
	I = 0;
	While I < arr2.Length
		If dst.Find(arr2[I], 0) < 0
			dst.Add(arr2[I], 1);
		EndIf
		I += 1;
	EndWhile	
	Return dst;
EndFunction

ObjectReference[] Function FindTerminalsNearby(Float afRadius)
;;	Return ConcatArrays(Game.GetPlayer().FindAllReferencesWithKeyword(AnimFurnTerminal_Standing, afRadius), ConcatArrays(Game.GetPlayer().FindAllReferencesWithKeyword(Terminal_Swap_Keyword01, afRadius), Game.GetPlayer().FindAllReferencesOfType(TradeAuthorityVendorKiosk, afRadius)));
	Return ConcatArrays(Game.GetPlayer().FindAllReferencesWithKeyword(AnimFurnTerminal_Standing, afRadius), Game.GetPlayer().FindAllReferencesWithKeyword(Terminal_Swap_Keyword01, afRadius));
EndFunction

Function InitTerminal(ObjectReference generic_term)
	generic_term.SetValue(HandScannerTarget, 1.0);
	generic_term.SetRequiresScanning(True);
	generic_term.SetScanned(False);	
EndFunction

ObjectReference[] Function SearchForTerminals(Float afRadius)
	ObjectReference[] generic_terms = FindTerminalsNearby(afRadius);
	ObjectReference[] out_list = new ObjectReference[0];
	
	Int I = 0;
	While I < generic_terms.Length
		ObjectReference generic_term = generic_terms[I];
		If generic_term.IsEnabled() && generic_term.Is3DLoaded()			
			InitTerminal(generic_term);
			out_list.Add(generic_term, 1);
		EndIf
		I += 1;
	EndWhile
	Return out_list;
EndFunction

Function ResetMissions(Bool abSilent = False)	
EndFunction

State ResetMissions_State

	Function ResetMissions(Bool abSilent = False)
		bResetMissionsQueued = False;			
		MB_Parent.ResetMissions(True, False, Game.GetPlayer().GetCurrentLocation(), True);
		If (!abSilent)
			Tip("QUEUED MISSIONS LIST RESET", "\n", "ЖЦEУЭД MI$$IOИ$ ЛI$T ЯE$ЭT");		
			Utility.Wait(3.0);
		EndIf
	EndFunction

EndState

;; ---- Ship builder ------------

Guard SpaceShipBuilder_Guard;

Function InitShipVendor()
	Self.RegisterForDistanceLessThanEvent(Game.GetPlayer() as ScriptObject, SQ_PlayerShip.PlayerShipPilotSeat.GetRef() as ScriptObject, 3.0, iPilotSeatIsNearID);	
	Self.RegisterForMenuOpenCloseEvent("SpaceshipEditorMenu") ; 

	ShipVendors = new ShipVendorStruct[0];
	ShipVendors.Add(new ShipVendorStruct, 1);
	ShipVendors[0].ShipVendor = RC(NPC_OutpostShipbuilderVendor);
	ShipVendors[0].Name = "";
	ShipVendors.Add(new ShipVendorStruct, 1);
	ShipVendors[1].ShipVendor = RC(NPC_NeonStroudStore_KioskVendor);
	ShipVendors[1].Name = "Stroud-Eklund\n";

	GLOB(GLOB_ShipBuilderAllowLargeModules).SetValue(1.0); ;; enable M modules
	GLOB(GLOB_ShipBuilderTestModules).SetValue(1.0);       ;; enable test modules

	GoToState("None");
EndFunction

Bool Function PilotSeatCondition(ObjectReference akScannedRef)
	Return akScannedRef == SQ_PlayerShip.PlayerShipPilotSeat.GetRef();
EndFunction

Bool Function IsInShip()
	Return Game.GetPlayer().IsInLocation(SQ_PlayerShip.PlayerShipInteriorLocation.GetLocation());
EndFunction

Function PilotSeatScanned(Actor akSource, ObjectReference akScannedRef)
	Guard SpaceShipBuilder_Guard
		If GetState() == "None"
			GoToState("CreateHangar_State");
			Tip("SHIP STORE DETECTED, WAIT", "\n", "ШЦIП $TOЯE ДETEKTЭД, ЩАIT");	
			CreateHangar();
		EndIf
	EndGuard
EndFunction

Function ProcessSpaceEditorMenu(Bool abOpening)
	bSpaceShipEditor = abOpening;
	if !bSpaceShipEditor
		ShipBuilderCleanup();	
		RestoreShip();
	EndIf
EndFunction

Event OnDistanceLessThan(ObjectReference akObj1, ObjectReference akObj2, Float afDistance, Int aiEventID)
	If aiEventID == iPilotSeatIsNearID
		Tip("PILOT SEAT PATCHED", "\n", "ЗИЛОТ ЗЭAT ПATЦЧЭД");
		ResetPilotSeat();
	EndIf
EndEvent

Function ResetPilotSeat()
	Dbg("ResetPilotSeat");
	InitTerminal(SQ_PlayerShip.PlayerShipPilotSeat.GetRef());
EndFunction

Function CreateHangar()
EndFunction

Function DeleteShipVendor()
	If ShipVendor != None
		Dbg("DeleteShipVendor");
		ShipVendor.Delete();
		ShipVendor = None;		
	EndIf
EndFunction

Bool Function CreateShipVendor()
	Return False;
EndFunction

Function ShowVendorMenu(Bool bForceRefresh = False)
EndFunction

Function ShipBuilderCleanup()
	DeleteShipVendor();
	GoToState("None");
	ResetPilotSeat();
EndFunction

State CreateHangar_State
	Function CreateHangar()
		Guard SpaceShipBuilder_Guard
			If !bSpaceShipEditor && GetState() == "CreateHangar_State"
				GoToState("CreateVendor_State");
				If CreateShipVendor()
					GoToState("ShowVendor_State");
					ShowVendorMenu(True);	
				Else
					Tip("NO ACCESS TO SHIP STORE", "\n", "C**A B***T DN1WE E****E");				
					ShipBuilderCleanup();
				EndIf
			Else
				ShipBuilderCleanup();
			EndIf	
		EndGuard
	EndFunction
EndState

State CreateVendor_State
	Bool Function CreateShipVendor()
		Guard SpaceShipBuilder_Guard;
			If GetState() == "CreateVendor_State"
				DeleteShipVendor();
				ShipVendorStruct Entry = new ShipVendorStruct;
				Entry = ShipVendors[Utility.RandomInt(0, ShipVendors.Length - 1)];
				SpaceShipReference ShipRef = SQ_PlayerShip.Frontier_ModularREF as SpaceShipReference;
				ShipVendor = ShipRef.PlaceAtMe(Entry.ShipVendor, 1, False, True, False, None, None, True) as ShipVendorScript;
				If SQ_PlayerShip.PlayerShipLandingMarker && SQ_PlayerShip.PlayerShipLandingMarker.GetRef()
					ShipVendor.MyLandingMarker = SQ_PlayerShip.PlayerShipLandingMarker.GetRef() ; 
				Else
					ShipVendor.MyLandingMarker = ShipVendor.PlaceAtMe(RC(59), 1, False, False, True, None, None, True) ; 
				Endif
				If !ShipVendor.InitializeOnLoad
					Return False;
				EndIf		
				If ShipVendor == None || ShipVendor.MyLandingMarker == None
					Return False;
				EndIf
				ShipVendorName = Entry.Name;
				Return True;
			Else
				Return False;
			EndIf
		EndGuard
	EndFunction
EndState

State ShowVendor_State
	Function ShowVendorMenu(Bool bForceRefresh = False)
		Guard SpaceShipBuilder_Guard;
			If GetState() == "ShowVendor_State"
				Tip(ShipVendorName, "SHIP STORE HACKED", "\n", "ШЦIП $TOЯE ФАЦКЭД");	
				GoToState("WaitForShopping_State");
				ShipVendor.CheckForInventoryRefresh(bForceRefresh);
;;				Int iAnswer = (RC(MESG_OutpostShipbuilderMessage) as Message).Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
				Int iAnswer = (RC(MESG_ShipbuilderActivatorMessage) as Message).Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
				Dbg(iAnswer as String);
				If (iAnswer >= 0)
					StoreShip();
					ShipVendor.MyLandingMarker.ShowHangarMenu(0, ShipVendor as Actor, None, iAnswer as Bool);
				Else
					ShipBuilderCleanup();
				EndIf
			Else
				ShipBuilderCleanup();
			EndIf
		EndGuard
	EndFunction	
EndState

Function StoreShip()
	CurrentPlace = None;
	CurrentShip = None;
	If IsInShip()
		CurrentShip = Game.GetPlayer().GetCurrentShipRef();
		CurrentShipIsLanded = CurrentShip.IsLanded();
		CurrentPlace = CurrentShip.PlaceAtMe(RC(59), 1, False, False, False, None, None, False) ; 
		CurrentPlace.MoveTo(CurrentPlace, -0.00000, 0.0, 0.0, True, False);
	EndIf	
EndFunction

Function RestoreShip()
	If IsInShip() && CurrentPlace as Bool && CurrentShip as Bool
		If !CurrentShip.IsInLocation(CurrentPlace.GetCurrentLocation())
			If !CurrentShipIsLanded
				CurrentShip.MoveTo(CurrentPlace, 0.00000, 0.0, 0.0, True, False);
				Game.FastTravel(CurrentShip);
				Utility.Wait(1.0);
			EndIf
		ElseIf CurrentShipIsLanded
			CurrentShip.MoveTo(CurrentPlace, 0.00000, 0.0, 0.0, True, False);
			Game.FastTravel(CurrentShip);
			Utility.Wait(1.0);			
		EndIf
		CurrentPlace.Delete();
		CurrentPlace = None;
		CurrentShip = None;
	EndIf
EndFunction

State WaitForShopping_State
	Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
		Dbg(asMenuName, " ", abOpening as String, ", state ", GetState());
		Guard SpaceShipBuilder_Guard
			If asMenuName == "MonocleMenu" 
				bHandScanner = abOpening;
				;; 'we are on the wrong side of it
				abOpening = False;
				asMenuname = "SpaceshipEditorMenu";
			EndIf
			If asMenuName == "SpaceshipEditorMenu" 
				bSpaceShipEditor = abOpening;
				If bSpaceShipEditor
				Else
					ShipBuilderCleanup();				
					RestoreShip();
				EndIf
			EndIf
		EndGuard
	EndEvent	
EndState