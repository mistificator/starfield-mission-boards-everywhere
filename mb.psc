ScriptName mb Extends ScriptObject
{Access to mission board on some standing terminals via scanner}

Int iFastTimerID = 1000 Const;
Float fFastTimerStep = 0.500001 Const; ;; 500 msec
Bool bResetMissionsQueued = False Global;
Bool bInResetMissions = False Global;
Bool bHandScanner = False Global;
Float fTerminalDistanceOpen = 3.0 Const; ;; 3 meters
Bool bSpaceShipEditor = False Global;
Int iPilotSeatIsNearID = 1000 Const;
ShipVendorScript Vendor = None;
Int iHangarMenuQueue = 0 Global;
String sStarfieldEsm = "Starfield.esm" Const;

Int KYWD_AnimFurnTerminal_Standing = 0x0025E8DE Const ;		;; KYWD
Keyword AnimFurnTerminal_Standing = None;
Int AVIF_HandScannerTarget = 0x0022A2B6 Const ;				;; AVIF
ActorValue HandScannerTarget = None ;
Int QUST_MB_Parent = 0x00015300 Const;						;; QUST
MissionParentScript MB_Parent = None;
Int QUST_SQ_PlayerShip = 0x000174A2 Const;					;; QUST
SQ_PlayerShipScript SQ_PlayerShip = None;

Int NPC_OutpostShipbuilderVendor = 0x0002F8FD;				;; NPC_
ActorBase OutpostShipbuilderVendor = None;

Event OnInit()
	Debug.Notification("MISSION BOARDS EVERYWHERE!\nMI$$IOИ BOAЯД$ ЭVEЯYФHEЯE!");
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnPlayerScannedObject");
	Self.RegisterForMenuOpenCloseEvent("MonocleMenu");
	Self.RegisterForMenuOpenCloseEvent("SpaceshipEditorMenu") ; 

	InitTerminalsSearch();
	InitShipVendor();
EndEvent

Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
	If asMenuName == "MonocleMenu" 
		bHandScanner = abOpening;
		If !bHandScanner && bResetMissionsQueued
			ResetMissions();
		EndIf
	EndIf	
	If asMenuname == "SpaceshipEditorMenu"
		bSpaceShipEditor = abOpening;
	EndIf
EndEvent

Event OnTimer(Int aTimerID)
	If aTimerID == iFastTimerID
		SearchForTerminals();
	EndIf
EndEvent

Event Actor.OnPlayerScannedObject(Actor akSource, ObjectReference akScannedRef)
	If akSource != Game.GetPlayer()
		Return;
	EndIf
	If akScannedRef.HasKeyword(AnimFurnTerminal_Standing)
		TerminalScanned(akSource, akScannedRef);
	Else
	If akScannedRef == SQ_PlayerShip.PlayerShipPilotSeat.GetRef()	
		PilotSeatScanned(akSource, akScannedRef);
	EndIf
	EndIf
EndEvent

;; ---- Mission boards ------------

Function InitTerminalsSearch()
	MB_Parent = Game.GetFormFromFile(QUST_MB_Parent, sStarfieldEsm) as MissionParentScript;
	HandScannerTarget = Game.GetFormFromFile(AVIF_HandScannerTarget, sStarfieldEsm) as ActorValue;
	AnimFurnTerminal_Standing = Game.GetFormFromFile(KYWD_AnimFurnTerminal_Standing, sStarfieldEsm) as Keyword;
	SearchForTerminals();
	ResetMissions(True);
EndFunction

Function TerminalScanned(Actor akSource, ObjectReference akScannedRef)
	If bInResetMissions
		Debug.Notification("NO ACCESS TO TERMINAL\nC**A B***T DN1WE E****E");
		Utility.Wait(3.0);
	EndIf
	Debug.Notification("TERMINAL DETECTED\nЩЭЯMIИAЛ ДETEKTЭД");		
	MB_Parent.UpdateMissions();
	Debug.Notification("TERMINAL HACKED\nЩЭЯMIИAЛ ФАЦКЭД");		
	Game.ShowMissionBoardMenu(None, Utility.RandomInt(1, 6));
	bResetMissionsQueued = True;
	akScannedRef.SetScanned(false);		
EndFunction

ObjectReference[] Function FindStandingTerminalsNearby()
	Return (Game.GetPlayer() as ObjectReference).FindAllReferencesWithKeyword(AnimFurnTerminal_Standing, fTerminalDistanceOpen);
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
	bInResetMissions = True;
	MB_Parent.ResetMissions(True, False, Game.GetPlayer().GetCurrentLocation(), True);
	If (!abSilent)
		Debug.Notification("QUEUED MISSIONS LIST RESET\nЖЦEУЭД MI$$IOИ$ ЛI$T ЯE$ЭT");		
		Utility.Wait(3.0);
	EndIf
	bResetMissionsQueued = False;			
	bInResetMissions = False;
EndFunction

;; ---- Ship builder ------------

Function InitShipVendor()
	SQ_PlayerShip = Game.GetFormFromFile(QUST_SQ_PlayerShip, sStarfieldEsm) as SQ_PlayerShipScript;
	Self.RegisterForDistanceLessThanEvent(Game.GetPlayer() as ScriptObject, SQ_PlayerShip.PlayerShipPilotSeat.GetRef() as ScriptObject, fTerminalDistanceOpen, iPilotSeatIsNearID);	
	OutpostShipbuilderVendor = Game.GetFormFromFile(NPC_OutpostShipbuilderVendor, sStarfieldEsm) as ActorBase;
	Self.RegisterForCustomEvent(Game.GetPlayer() as ScriptObject, "Actor_OnHangarMenuQueued");
EndFunction

Function PilotSeatScanned(Actor akSource, ObjectReference akScannedRef)
	If GetState() == "SpaceShipBuilder"
		Return;
	EndIf
	GoToState("SpaceShipBuilder");
	If iHangarMenuQueue == 0
		iHangarMenuQueue += 1;
		Debug.Notification("SHIP STORE DETECTED, WAIT\nШЦIП $TOЯE ДETEKTЭД, ЩАIT");	
		
		Var[] args = new Var[2] ;
		args[0] = akSource as Var;
		args[1] = akScannedRef as Var;
		Game.GetPlayer().SendCustomEvent("Actor_OnHangarMenuQueued", args);
		Return;
	EndIf
	GoToState("None");
EndFunction

Event OnDistanceLessThan(ObjectReference akObj1, ObjectReference akObj2, Float afDistance, Int aiEventID)
	If aiEventID == iPilotSeatIsNearID && akObj2 == SQ_PlayerShip.PlayerShipPilotSeat.GetRef()	
		Debug.Notification("PILOT SEAT PATCHED\nЗИЛОТ ЗЭAT ПATЦЧЭД");
		akObj2.SetValue(HandScannerTarget, 1.0);
		akObj2.SetRequiresScanning(true);
		akObj2.SetScanned(false);		
	EndIf
EndEvent

Event Actor.OnHangarMenuQueued(Actor akSender, Var[] akArgs)
	If iHangarMenuQueue > 0
		iHangarMenuQueue -= 1;
	EndIf
EndEvent

Function DeleteVendor()
EndFunction

Bool Function CreateVendor()
	Return False;
EndFunction

Function ShowVendorMenu(Bool bForceRefresh = False)
EndFunction

State SpaceShipBuilder
	Event Actor.OnHangarMenuQueued(Actor akSender, Var[] akArgs)
		If iHangarMenuQueue > 0
			iHangarMenuQueue -= 1;
		EndIf
		If !bSpaceShipEditor && bHandScanner && iHangarMenuQueue == 0
			ObjectReference akScannedRef = akArgs[1] as ObjectReference;
			akScannedRef.SetScanned(false);
			If CreateVendor()
				ShowVendorMenu(True);	
			Else
				Debug.Notification("NO ACCESS TO SHIP STORE\nC**A B***T DN1WE E****E");				
			EndIf
		EndIf	
	EndEvent
	
	Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
		If asMenuName == "MonocleMenu" 
			bHandScanner = abOpening;
		EndIf
		If asMenuname == "SpaceshipEditorMenu" 
			bSpaceShipEditor = abOpening;
		EndIf
		If asMenuname == "SpaceshipEditorMenu" || asMenuName == "MonocleMenu" 
			If !abOpening
				DeleteVendor();
				bSpaceShipEditor = abOpening;
				bHandScanner = abOpening;
				GoToState("None");
			EndIf
		EndIf
	EndEvent	

	Function DeleteVendor()
		If Vendor != None
			Vendor.Delete();
			Vendor = None;		
		EndIf
	EndFunction
	
	Bool Function CreateVendor()
		DeleteVendor();
		Vendor = SQ_PlayerShip.PlayerShip.GetRef().PlaceAtMe(OutpostShipbuilderVendor, 1, False, True, False, None, None, True) as ShipVendorScript;
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
		Return True;
	EndFunction

	Function ShowVendorMenu(Bool bForceRefresh = False)
		Debug.Notification("SHIP STORE HACKED\nШЦIП $TOЯE ФАЦКЭД");		
		bSpaceShipEditor = True;
		Vendor.CheckForInventoryRefresh(bForceRefresh);
		Utility.Wait(0.5);
		Vendor.myLandingMarker.ShowHangarMenu(0, Vendor, SQ_PlayerShip.PlayerShip.GetShipReference(), False);
		Utility.Wait(0.5);
	EndFunction	
EndState

