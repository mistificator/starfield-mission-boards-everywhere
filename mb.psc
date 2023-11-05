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
			If !abOpening && bResetMissionsQueued
				ResetMissions();
			EndIf
			bHandScanner = abOpening;
		EndIf	
		If asMenuname == "SpaceshipEditorMenu"
			If !abOpening
				DeleteVendor();
			EndIf
	;;		Debug.Notification(asMenuName + " " + abOpening as String);
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
EndFunction

Function PilotSeatScanned(Actor akSource, ObjectReference akScannedRef)
	If iHangarMenuQueue == 0
		iHangarMenuQueue += 1;
		Debug.Notification("SHIP STORE DETECTED, WAIT\nШЦIП $TOЯE ДETEKTЭД, ЩАIT");	
		
		Self.RegisterForCustomEvent(Game.GetPlayer() as ScriptObject, "Actor_OnHangarMenuQueued");
		Var[] args = new Var[2] ;
		args[0] = akSource as Var;
		args[1] = akScannedRef as Var;
		Game.GetPlayer().SendCustomEvent("Actor_OnHangarMenuQueued", args);
	EndIf
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
	Self.UnregisterForCustomEvent(Game.GetPlayer() as ScriptObject, "Actor_OnHangarMenuQueued");
	If !bSpaceShipEditor
		If iHangarMenuQueue > 0
			iHangarMenuQueue -= 1;
		EndIf
		If iHangarMenuQueue == 0
			ObjectReference akScannedRef = akArgs[1] as ObjectReference;
			akScannedRef.SetScanned(false);
			DeleteVendor();
			CreateVendor();
			ShowVendorMenu();	
		EndIf	
	EndIf
EndEvent

Guard DeleteVendor_Guard;
Function DeleteVendor()
	Guard DeleteVendor_Guard;
		If Vendor
			Vendor.Delete();
			Vendor = None;		
		EndIf
	EndGuard;
EndFunction

Function CreateVendor()
	Vendor = SQ_PlayerShip.PlayerShip.GetRef().PlaceAtMe(OutpostShipbuilderVendor, 1, False, True, True, None, None, True) as ShipVendorScript;
	If SQ_PlayerShip.PlayerShipLandingMarker && SQ_PlayerShip.PlayerShipLandingMarker.GetRef()
		Vendor.myLandingMarker = SQ_PlayerShip.PlayerShipLandingMarker.GetRef(); 
	Else
		Vendor.myLandingMarker = Vendor.PlaceAtMe(Game.GetFormFromFile(59, sStarfieldEsm), 1, False, False, True, None, None, True) ; 
	Endif
	If !Vendor.InitializeOnLoad
		Vendor.Initialize(vendor.myLandingMarker);
	EndIf
;;	Debug.Notification("OutpostShipbuilderVendor " + (OutpostShipbuilderVendor as String) + "\nVendor " + (Vendor as String) + "\nVendor loc " + (Vendor.myLandingMarker as String) + "\nPlayer loc " + (Game.GetPlayer().GetCurrentLocation() as String));
EndFunction

Function ShowVendorMenu()
	Debug.Notification("SHIP STORE HACKED\nШЦIП $TOЯE ФАЦКЭД");		
	bSpaceShipEditor = True;
	Vendor.myLandingMarker.ShowHangarMenu(0, Vendor, None, False);
EndFunction