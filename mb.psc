ScriptName mb Extends ScriptObject
{Mission board on every standing terminal}

Int iTimerID = 1000 Const;
Float fTimeStep = 0.500001 Const; ;; 500 msec

Float fTerminalDistanceOpen = 3.0 Const; ;; 3 meters

String StarfieldEsm = "Starfield.esm" Const;

Int KYWD_AnimFurnTerminal_Standing = 0x0025E8DE Const 		;; KYWD
Keyword AnimFurnTerminal_Standing = None;
Int AVIF_MissionBoardAvailable_Supply = 0x0039F887      	;; AVIF
ActorValue MissionBoardAvailable_Supply = None;
Int AVIF_MissionBoardAvailable_Hunt = 0x0039F888      		;; AVIF
ActorValue MissionBoardAvailable_Hunt = None;

Event OnInit()
	Debug.Notification("MISSION BOARDS EVERYWHERE!\nMI$$IOИ BOAЯД$ ЭVEЯYФHEЯE!");
	MissionBoardAvailable_Supply = Game.GetFormFromFile(AVIF_MissionBoardAvailable_Supply, StarfieldEsm) as ActorValue;
	MissionBoardAvailable_Hunt = Game.GetFormFromFile(AVIF_MissionBoardAvailable_Hunt, StarfieldEsm) as ActorValue;
	AnimFurnTerminal_Standing = Game.GetFormFromFile(KYWD_AnimFurnTerminal_Standing, StarfieldEsm) as Keyword;
	Self.StartTimer(fTimeStep, iTimerID) ;
EndEvent

ObjectReference[] Function FindStandingTerminalsNearby()
	Return (Game.GetPlayer() as ObjectReference).FindAllReferencesWithKeyword(AnimFurnTerminal_Standing, fTerminalDistanceOpen);
EndFunction

Event OnTimer(Int aTimerID)
	If aTimerID == iTimerID
		ObjectReference[] generic_standing_terms = Self.FindStandingTerminalsNearby();
		Int I = 0;
		While I < generic_standing_terms.Length
			ObjectReference generic_standing_term = generic_standing_terms[I];
			If generic_standing_term.IsEnabled() && generic_standing_term.Is3DLoaded()			
				TerminalScript term = generic_standing_term as TerminalScript;				
				If term && term.GetValue(MissionBoardAvailable_Supply) == 0.0 && term.GetValue(MissionBoardAvailable_Hunt) == 0.0
					Debug.Notification("TERMINAL DETECTED\nЩЭЯMIИAЛ ДETEKTЭД");
					Debug.ExecuteConsole(Utility.IntToHex((term as Form).GetFormID()) + ".AttachPapyrusScript MissionBoardActivatorScript");
					Utility.Wait(2.0);
					MissionBoardActivatorScript mbas = generic_standing_term as MissionBoardActivatorScript;
					If mbas
						mbas.SetValue(MissionBoardAvailable_Supply, 1.0);
						mbas.SetValue(MissionBoardAvailable_Hunt, 1.0);
						Debug.Notification("TERMINAL HACKED\nЩЭЯMIИAЛ ФАЦКЭД");
					Else
						Debug.Notification("NO ACCESS TO TERMINAL\nCYKA BLYAT DNIWE EBANOE");
					EndIf
				EndIf
			EndIf
			I += 1;
		EndWhile
		StartTimer(fTimeStep, iTimerID);
	EndIf
EndEvent

