ScriptName ScanEx Extends ScriptObject

Int iFastTimerID = 1000 Const;
Float fFastTimerStep = 0.500001 Const; ;; 500 msec
Bool bResetMissionsQueued = False Global;
Bool bHandScanner = False Global;
Float fTerminalDistanceOpen = 3.0 Const; ;; 3 meters
Bool bSpaceShipEditor = False Global;
Int iPilotSeatIsNearID = 1000 Const;
ShipVendorScript Vendor = None;
String VendorName = "";
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
      
Struct ShipVendorStruct
	Form Vendor = None;
	String Name = "";
EndStruct
ShipVendorStruct[] Vendors;

;; ---- Common part -----

Event OnInit()
	Debug.Notification("USE SCANEX EVERYWHERE!\nЮЗE $ЦAИЭX ЭVEЯYФHEЯE!");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnPlayerScannedObject");
	Self.RegisterForMenuOpenCloseEvent("MonocleMenu");
	Self.RegisterForMenuOpenCloseEvent("SpaceshipEditorMenu") ; 

	InitTerminalsSearch();
	InitShipVendor();
EndEvent

Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
	If asMenuName == "MonocleMenu" 
		ProcessMonocleMenu(abOpening);
	EndIf	
	If asMenuname == "SpaceshipEditorMenu"
		ProcessSpaceEditorMenu(abOpening);
	EndIf
EndEvent

Event OnTimer(Int aTimerID)
	If aTimerID == iFastTimerID
		If bHandScanner
			SearchForTerminals();
		EndIf
	EndIf
EndEvent

Event Actor.OnPlayerScannedObject(Actor akSource, ObjectReference akScannedRef)
	If akSource != Game.GetPlayer()
		Return;
	EndIf
	If TerminalCondition(akScannedRef)
		TerminalScanned(akSource, akScannedRef);
	Else
	If PilotSeatCondition(akScannedRef)
		PilotSeatScanned(akSource, akScannedRef);
	EndIf
	EndIf
EndEvent

;; ---- Mission boards ------------

Function InitTerminalsSearch()
	MB_Parent = Game.GetFormFromFile(QUST_MB_Parent, sStarfieldEsm) as MissionParentScript;
	HandScannerTarget = Game.GetFormFromFile(AVIF_HandScannerTarget, sStarfieldEsm) as ActorValue;
	AnimFurnTerminal_Standing = Game.GetFormFromFile(KYWD_AnimFurnTerminal_Standing, sStarfieldEsm) as Keyword;
	TradeAuthorityVendorKiosk = Game.GetFormFromFile(ACTI_TradeAuthorityVendorKiosk, sStarfieldEsm);
	GoToState("ResetMissions_State");
	ResetMissions(True);
	GoToState("None");
EndFunction

Bool Function TerminalCondition(ObjectReference akScannedRef)
	Return akScannedRef.HasKeyword(AnimFurnTerminal_Standing) || akScannedRef.GetBaseObject() == TradeAuthorityVendorKiosk;
EndFunction

Function TerminalScanned(Actor akSource, ObjectReference akScannedRef)
	If GetState() == "ShowMissions_State"
		Return;
	EndIf
	If GetState() != "None"
		Debug.Notification("NO ACCESS TO TERMINAL\nC**A B***T DN1WE E****E");
		Return;
	EndIf
	GoToState("ShowMissions_State")
	ShowMissions(akScannedRef);
	GoToState("None");	
EndFunction

Function ProcessMonocleMenu(Bool abOpening)
	bHandScanner = abOpening;
	If bHandScanner
		SearchForTerminals();
	Else
		If bResetMissionsQueued && GetState() != "ResetMissions_State"
			GoToState("ResetMissions_State");
			ResetMissions();
		EndIf
		GoToState("None");
	EndIf
EndFunction

Function ShowMissions(ObjectReference akScannedRef)
EndFunction

State ShowMissions_State
	Function ShowMissions(ObjectReference akScannedRef)
		Debug.Notification("TERMINAL DETECTED\nЩЭЯMIИAЛ ДETEKTЭД");		
		MB_Parent.UpdateMissions();
		Debug.Notification("TERMINAL HACKED\nЩЭЯMIИAЛ ФАЦКЭД");		
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

ObjectReference[] Function FindStandingTerminalsNearby()
	Return ConcatArrays(Game.GetPlayer().FindAllReferencesWithKeyword(AnimFurnTerminal_Standing, fTerminalDistanceOpen), Game.GetPlayer().FindAllReferencesOfType(TradeAuthorityVendorKiosk, fTerminalDistanceOpen));
EndFunction

Function SearchForTerminals()
	ObjectReference[] generic_standing_terms = FindStandingTerminalsNearby();
	Int I = 0;
	While I < generic_standing_terms.Length
		ObjectReference generic_standing_term = generic_standing_terms[I];
		If generic_standing_term.IsEnabled() && generic_standing_term.Is3DLoaded()			
			generic_standing_term.SetValue(HandScannerTarget, 1.0);
			generic_standing_term.SetRequiresScanning(true);
			generic_standing_term.SetScanned(false);
		EndIf
		I += 1;
	EndWhile
	StartTimer(fFastTimerStep, iFastTimerID);
EndFunction

Function ResetMissions(Bool abSilent = False)	
EndFunction

State ResetMissions_State

	Function ResetMissions(Bool abSilent = False)
		MB_Parent.ResetMissions(True, False, Game.GetPlayer().GetCurrentLocation(), True);
		If (!abSilent)
			Debug.Notification("QUEUED MISSIONS LIST RESET\nЖЦEУЭД MI$$IOИ$ ЛI$T ЯE$ЭT");		
			Utility.Wait(3.0);
		EndIf
		bResetMissionsQueued = False;			
	EndFunction

EndState

;; ---- Ship builder ------------

Guard SpaceShipBuilder_Guard;

Function InitShipVendor()
	SQ_PlayerShip = Game.GetFormFromFile(QUST_SQ_PlayerShip, sStarfieldEsm) as SQ_PlayerShipScript;
	Self.RegisterForDistanceLessThanEvent(Game.GetPlayer() as ScriptObject, SQ_PlayerShip.PlayerShipPilotSeat.GetRef() as ScriptObject, fTerminalDistanceOpen, iPilotSeatIsNearID);	

	Vendors = new ShipVendorStruct[0];
	Vendors.Add(new ShipVendorStruct, 1);
	Vendors[0].Vendor = Game.GetFormFromFile(NPC_OutpostShipbuilderVendor, sStarfieldEsm);
	Vendors[0].Name = "";
	Vendors.Add(new ShipVendorStruct, 1);
	Vendors[1].Vendor = Game.GetFormFromFile(NPC_NeonStroudStore_KioskVendor, sStarfieldEsm);
	Vendors[1].Name = "Stroud-Eklund\n";

	(Game.GetFormFromFile(GLOB_ShipBuilderAllowLargeModules, sStarfieldEsm) as GlobalVariable).SetValue(1.0); ;; enable M modules
	(Game.GetFormFromFile(GLOB_ShipBuilderTestModules, sStarfieldEsm) as GlobalVariable).SetValue(1.0);       ;; enable test modules
EndFunction

Bool Function PilotSeatCondition(ObjectReference akScannedRef)
	Return akScannedRef == SQ_PlayerShip.PlayerShipPilotSeat.GetRef();
EndFunction

Function PilotSeatScanned(Actor akSource, ObjectReference akScannedRef)
	Guard SpaceShipBuilder_Guard;
		While (GetState() != "None")
			Utility.Wait(1.0);
		EndWhile
		GoToState("CreateHangar_State");
		Debug.Notification("SHIP STORE DETECTED, WAIT\nШЦIП $TOЯE ДETEKTЭД, ЩАIT");	
		CreateHangar();
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
		Debug.Notification("PILOT SEAT PATCHED\nЗИЛОТ ЗЭAT ПATЦЧЭД");
		ResetPilotSeat();
	EndIf
EndEvent

Function ResetPilotSeat()
	SQ_PlayerShip.PlayerShipPilotSeat.GetRef().SetValue(HandScannerTarget, 1.0);
	SQ_PlayerShip.PlayerShipPilotSeat.GetRef().SetRequiresScanning(true);
	SQ_PlayerShip.PlayerShipPilotSeat.GetRef().SetScanned(false);	
EndFunction

Function CreateHangar()
EndFunction

Function DeleteVendor()
	If Vendor != None
		Vendor.Delete();
		Vendor = None;		
	EndIf
EndFunction

Bool Function CreateVendor()
	Return False;
EndFunction

Function ShowVendorMenu(Bool bForceRefresh = False)
EndFunction

State CreateHangar_State
	Function CreateHangar()
		Guard SpaceShipBuilder_Guard;
			If !bSpaceShipEditor && bHandScanner && GetState() == "CreateHangar_State"
				GoToState("ShowHangar_State");
				If CreateVendor()
					ShowVendorMenu(True);	
				Else
					Debug.Notification("NO ACCESS TO SHIP STORE\nC**A B***T DN1WE E****E");				
					GoToState("None");
					ResetPilotSeat();
				EndIf
			EndIf	
		EndGuard
	EndFunction
EndState

State ShowHangar_State
	Bool Function CreateVendor()
		DeleteVendor();
		ShipVendorStruct Entry = new ShipVendorStruct;
		Entry = Vendors[Utility.RandomInt(0, Vendors.Length - 1)];
		Vendor = SQ_PlayerShip.PlayerShip.GetRef().PlaceAtMe(Entry.Vendor, 1, False, True, False, None, None, True) as ShipVendorScript;
		If SQ_PlayerShip.PlayerShipLandingMarker && SQ_PlayerShip.PlayerShipLandingMarker.GetRef()
			Vendor.myLandingMarker = SQ_PlayerShip.PlayerShipLandingMarker.GetRef(); 
		Else
			Vendor.myLandingMarker = Vendor.PlaceAtMe(Game.GetFormFromFile(59, sStarfieldEsm), 1, False, False, True, None, None, True) ; 
		Endif
		If !Vendor.InitializeOnLoad
			DeleteVendor();
			Return False;
		EndIf		
		If Vendor == None || Vendor.myLandingMarker == None
			DeleteVendor();
			Return False;
		EndIf
		VendorName = Entry.Name;
		Return True;
	EndFunction

	Function ShowVendorMenu(Bool bForceRefresh = False)
		Debug.Notification(VendorName + "SHIP STORE HACKED\nШЦIП $TOЯE ФАЦКЭД");	
		bSpaceShipEditor = True;
		Vendor.CheckForInventoryRefresh(bForceRefresh);
		Vendor.myLandingMarker.ShowHangarMenu(0, Vendor as Actor, None, False);
		GoToState("WaitForShopping_State");
	EndFunction	
EndState

State WaitForShopping_State
	Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
		Guard SpaceShipBuilder_Guard;
			If asMenuName == "MonocleMenu" 
				bHandScanner = abOpening;
			EndIf
			If asMenuname == "SpaceshipEditorMenu" 
				bSpaceShipEditor = abOpening;
				If !abOpening
					DeleteVendor();
					GoToState("None");
					ResetPilotSeat();
				EndIf
			EndIf
		EndGuard
	EndEvent	
EndState