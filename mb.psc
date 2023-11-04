ScriptName mb Extends ScriptObject
{Access to mission board on some standing terminals via scanner}

Int iFastTimerID = 1000 Const;
Float fFastTimerStep = 0.500001 Const; ;; 500 msec
Bool bResetMissionsQueued = False;
Bool bInResetMissions = False;
Bool bHandScanner = False;
Float fTerminalDistanceOpen = 3.0 Const; ;; 3 meters
String sStarfieldEsm = "Starfield.esm" Const;

Int KYWD_AnimFurnTerminal_Standing = 0x0025E8DE Const ;		;; KYWD
Keyword AnimFurnTerminal_Standing = None;
Int AVIF_HandScannerTarget = 0x0022A2B6 Const ;				;; AVIF
ActorValue HandScannerTarget = None ;
Int QUST_MB_Parent = 0x00015300 Const;						;; QUST
MissionParentScript MB_Parent = None;

Event OnInit()
	Debug.Notification("MISSION BOARDS EVERYWHERE!\nMI$$IOИ BOAЯД$ ЭVEЯYФHEЯE!");
	MB_Parent = Game.GetFormFromFile(QUST_MB_Parent, sStarfieldEsm) as MissionParentScript;
	HandScannerTarget = Game.GetFormFromFile(AVIF_HandScannerTarget, sStarfieldEsm) as ActorValue;
	AnimFurnTerminal_Standing = Game.GetFormFromFile(KYWD_AnimFurnTerminal_Standing, sStarfieldEsm) as Keyword;
	Self.RegisterForRemoteEvent(Game.GetPlayer(), "OnPlayerScannedObject");
	Self.RegisterForMenuOpenCloseEvent("MonocleMenu");
	Self.StartTimer(fFastTimerStep, iFastTimerID) ;
	ResetMissions(True);
EndEvent

ObjectReference[] Function FindStandingTerminalsNearby()
	Return (Game.GetPlayer() as ObjectReference).FindAllReferencesWithKeyword(AnimFurnTerminal_Standing, fTerminalDistanceOpen);
EndFunction

Event OnTimer(Int aTimerID)
	If aTimerID == iFastTimerID
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
	EndIf
EndEvent

Event Actor.OnPlayerScannedObject(Actor akSource, ObjectReference akScannedRef)
	If akSource != Game.GetPlayer()
		Return;
	EndIf
	If !akScannedRef.HasKeyword(AnimFurnTerminal_Standing)
		Return;
	EndIf
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
EndEvent

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

Event OnMenuOpenCloseEvent(String asMenuName, Bool abOpening)
	If asMenuName == "MonocleMenu" 
		bHandScanner = abOpening;
		If !bHandScanner && bResetMissionsQueued
			ResetMissions();
		EndIf
	EndIf
EndEvent