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
Int ACTI_TradeAuthorityVendorKiosk = 0x001150B3 Const;		;; ACTI
Form TradeAuthorityVendorKiosk = None;
Int AVIF_HandScannerTarget = 0x0022A2B6 Const ;				;; AVIF
ActorValue HandScannerTarget = None ;
Int QUST_MB_Parent = 0x00015300 Const;						;; QUST
MissionParentScript MB_Parent = None;
Int QUST_SQ_PlayerShip = 0x000174A2 Const;					;; QUST
SQ_PlayerShipScript SQ_PlayerShip = None;

Int GLOB_ShipBuilderAllowLargeModules = 0x00155F4A;			;; GLOB
Int GLOB_ShipBuilderTestModules = 0x00141C71;				;; GLOB

Int NPC_OutpostShipbuilderVendor = 0x0002F8FD;				;; NPC_
Int NPC_NeonStroudStore_KioskVendor = 0x00151488;			;; NPC_

Int MESG_OutpostShipbuilderMessage = 0x0002F8FE;			;; MESG
Int MESG_ShipbuilderActivatorMessage = 0x0002EE15;			;; MESG
      
Struct ShipVendorStruct
	Form ShipVendor = None;
	String Name = "";
EndStruct
ShipVendorStruct[] ShipVendors;

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

Event OnInit()
	Tip("USE SCANEX EVERYWHERE!", "\n", "ЮЗE $ЦAИЭX ЭVEЯYФHEЯE!");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnPlayerScannedObject");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnLocationChange");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnEnterShipInterior");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnExitShipInterior");
	Self.RegisterForMenuOpenCloseEvent("MonocleMenu");

	SQ_PlayerShip = Game.GetFormFromFile(QUST_SQ_PlayerShip, sStarfieldEsm) as SQ_PlayerShipScript;
	MB_Parent = Game.GetFormFromFile(QUST_MB_Parent, sStarfieldEsm) as MissionParentScript;
	HandScannerTarget = Game.GetFormFromFile(AVIF_HandScannerTarget, sStarfieldEsm) as ActorValue;
	AnimFurnTerminal_Standing = Game.GetFormFromFile(KYWD_AnimFurnTerminal_Standing, sStarfieldEsm) as Keyword;
	TradeAuthorityVendorKiosk = Game.GetFormFromFile(ACTI_TradeAuthorityVendorKiosk, sStarfieldEsm);

	UpdateLocationChange();
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

;; ---- Mission boards ------------

Function InitTerminalsSearch()
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
	Int I = 0;
	While I < obj_refs.Length
		If (obj_refs[I].GetBaseObject() == TradeAuthorityVendorKiosk)	
			InitTerminal(ReCreateObject(obj_refs[I]));
			DbgObj(obj_refs[I]);
		EndIf
		I += 1;
	EndWhile
	If I > 0
		Tip(I as String, " TERMINALS FOUND", "\n", I as String, " ЩЭЯMIИAЛ$ ЪOУИД");
	EndIf
	EndGuard
EndFunction

Bool Function TerminalCondition(ObjectReference akScannedRef)
	Return akScannedRef.HasKeyword(AnimFurnTerminal_Standing) || akScannedRef.GetBaseObject() == TradeAuthorityVendorKiosk;
EndFunction

Function TerminalScanned(Actor akSource, ObjectReference akScannedRef)
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
		akScannedRef.SetScanned(false);	
	EndFunction
EndState

ObjectReference[] Function ConcatArrays(ObjectReference[] arr1, ObjectReference[] arr2)
	ObjectReference[] dst = new ObjectReference[0];
	Int I = 0;
	While I < arr1.Length
		dst.Add(arr1[I], 1);
		I += 1;
	EndWhile	
	I = 0;
	While I < arr2.Length
		dst.Add(arr2[I], 1);
		I += 1;
	EndWhile	
	Return dst;
EndFunction

ObjectReference[] Function FindStandingTerminalsNearby(Float afRadius)
	Return ConcatArrays(Game.GetPlayer().FindAllReferencesWithKeyword(AnimFurnTerminal_Standing, afRadius), Game.GetPlayer().FindAllReferencesOfType(TradeAuthorityVendorKiosk, afRadius));
EndFunction

Function InitTerminal(ObjectReference generic_standing_term)
	generic_standing_term.SetValue(HandScannerTarget, 1.0);
	generic_standing_term.SetRequiresScanning(true);
	generic_standing_term.SetScanned(false);
EndFunction

ObjectReference[] Function SearchForTerminals(Float afRadius)
	ObjectReference[] generic_standing_terms = FindStandingTerminalsNearby(afRadius);
	ObjectReference[] out_list = new ObjectReference[0];
	Int I = 0;
	While I < generic_standing_terms.Length
		ObjectReference generic_standing_term = generic_standing_terms[I];
		If generic_standing_term.IsEnabled() && generic_standing_term.Is3DLoaded()			
			InitTerminal(generic_standing_term);
			out_list.Add(generic_standing_term, 1);
		EndIf
		I += 1;
	EndWhile
	Return out_list;
EndFunction

Function ResetMissions(Bool abSilent = False)	
EndFunction

State ResetMissions_State

	Function ResetMissions(Bool abSilent = False)
		MB_Parent.ResetMissions(True, False, Game.GetPlayer().GetCurrentLocation(), True);
		If (!abSilent)
			Tip("QUEUED MISSIONS LIST RESET", "\n", "ЖЦEУЭД MI$$IOИ$ ЛI$T ЯE$ЭT");		
			Utility.Wait(3.0);
		EndIf
		bResetMissionsQueued = False;			
	EndFunction

EndState

;; ---- Ship builder ------------

Guard SpaceShipBuilder_Guard;

Function InitShipVendor()
	Self.RegisterForDistanceLessThanEvent(Game.GetPlayer() as ScriptObject, SQ_PlayerShip.PlayerShipPilotSeat.GetRef() as ScriptObject, 3.0, iPilotSeatIsNearID);	
	Self.RegisterForMenuOpenCloseEvent("SpaceshipEditorMenu") ; 

	ShipVendors = new ShipVendorStruct[0];
	ShipVendors.Add(new ShipVendorStruct, 1);
	ShipVendors[0].ShipVendor = Game.GetFormFromFile(NPC_OutpostShipbuilderVendor, sStarfieldEsm);
	ShipVendors[0].Name = "";
	ShipVendors.Add(new ShipVendorStruct, 1);
	ShipVendors[1].ShipVendor = Game.GetFormFromFile(NPC_NeonStroudStore_KioskVendor, sStarfieldEsm);
	ShipVendors[1].Name = "Stroud-Eklund\n";

	(Game.GetFormFromFile(GLOB_ShipBuilderAllowLargeModules, sStarfieldEsm) as GlobalVariable).SetValue(1.0); ;; enable M modules
	(Game.GetFormFromFile(GLOB_ShipBuilderTestModules, sStarfieldEsm) as GlobalVariable).SetValue(1.0);       ;; enable test modules

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
		ResetPilotSeat();
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
	SQ_PlayerShip.PlayerShipPilotSeat.GetRef().SetValue(HandScannerTarget, 1.0);
	SQ_PlayerShip.PlayerShipPilotSeat.GetRef().SetRequiresScanning(true);
	SQ_PlayerShip.PlayerShipPilotSeat.GetRef().SetScanned(false);	
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
				ShipVendor = SQ_PlayerShip.PlayerShip.GetRef().PlaceAtMe(Entry.ShipVendor, 1, False, True, False, None, None, True) as ShipVendorScript;
				If SQ_PlayerShip.PlayerShipLandingMarker && SQ_PlayerShip.PlayerShipLandingMarker.GetRef()
					ShipVendor.MyLandingMarker = SQ_PlayerShip.PlayerShipLandingMarker.GetRef(); 
				Else
					ShipVendor.MyLandingMarker = ShipVendor.PlaceAtMe(Game.GetFormFromFile(59, sStarfieldEsm), 1, False, False, True, None, None, True) ; 
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
;;				Int iAnswer = (Game.GetFormFromFile(MESG_OutpostShipbuilderMessage, sStarfieldEsm) as Message).Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
				Int iAnswer = (Game.GetFormFromFile(MESG_ShipbuilderActivatorMessage, sStarfieldEsm) as Message).Show(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
				Dbg(iAnswer as String);
				If (iAnswer >= 0)
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
			If asMenuname == "SpaceshipEditorMenu" 
				bSpaceShipEditor = abOpening;
				If !bSpaceShipEditor
					ShipBuilderCleanup();
				EndIf
			EndIf
		EndGuard
	EndEvent	
EndState