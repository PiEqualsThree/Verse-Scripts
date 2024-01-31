using { /Fortnite.com/Characters }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Game }
using { /Fortnite.com/UI }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /Verse.org/Assets }
using { /Verse.org/Colors }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /UnrealEngine.com/Temporary/UI }

StringToText<localizes>(String : string) : message = "{String}"

loadout_vote_selection_device := class(creative_device):
    @editable       Rows : type{ _X : int where _X > 0, _X < 4} = 1
    @editable       Columns : type{_X : int where _X > 1, _X < 6} = 3
    @editable       VotingTime : type{ _X : int where _X >= 3, _X <= 30} = 10
    @editable       Loadouts : []loadout = array{}
    var LoadoutToCurrentVotes : [loadout]int = map{}
    var MaxVotes : int = 0
    var CurrentVotes : int = 0
    var ImageSize : vector2 = vector2{}
    # PUT YOUR TEXTURES HERE, IN THE ORDER OF LAYOUT!! :D
    Textures : []texture = array:
        # UITexture.FirstImage
        # UITexture.SecondImage
        # UITexture.ThirdImage
        # etc . . .
    VoteEndedEvent<private> : event() = event(){}
    PlayerSelectionEvent<private> : event(button_selection_result) = event(button_selection_result){}

    # Call this to begin the loadout selection phase
    InitLoadoutSelection(Players : []player)<suspends> : void =
        set ImageSize = (1500.0 / (1.0 * Rows)) * vector2{ X := 1.0, Y := 1.0}
        for (Loadout : Loadouts, set LoadoutToCurrentVotes[Loadout] = 0) {}
        set MaxVotes = Loadouts.Length
        set CurrentVotes = 0
        for ( Player : Players):
            spawn{ PresentSelectionUI(Player) }
        VoteEndedEvent.Await()
        WinningLoadout := CalculateMostVotedLoadout()
        for ( Player : Players):
            WinningLoadout.ItemGranter.GrantItem(Player)

    # Present the Loadout UI to a player
    PresentSelectionUI(Player : player)<suspends> : void =
        var SelectionButtons : []button_regular = array{}
        # Create our selection buttons with the respective loadout name
        for ( Loadout : Loadouts):
            set SelectionButtons += array:
                button_regular:
                    DefaultText := StringToText(Loadout.Name)

        if ( PlayerUI := GetPlayerUI[Player]):
            var TimeRemaining : int = int[VotingTime] or 10
            TimerTextBlock := text_block{DefaultText := StringToText("Choose your vote!: {TimeRemaining}")}
            branch:
                loop:
                    Sleep(1.0)
                    set TimeRemaining -= 1
                    TimerTextBlock.SetText(StringToText("Choose your vote!: {TimeRemaining}"))
                    if (TimeRemaining = 0) then Sleep(3.0)
            Canvas : canvas = canvas:
                Slots := array:
                    canvas_slot:
                        Widget := ConstructMainUI(SelectionButtons, TimerTextBlock)
            PlayerUI.AddWidget(Canvas)
            race:
                VoteEndedEvent.Await()
                loop:
                    SelectionResult := PlayerSelectionEvent.Await()
                    if ( Votes := LoadoutToCurrentVotes[SelectionResult.Index], ButtonToUpdate := SelectionButtons[SelectionResult.Index]):
                        ButtonToUpdate.SetText(StringToText("{Votes}"))
                    if( Player = SelectionResult.Player ):
                        for ( Button : SelectionButtons) {Button.SetEnabled(false)}
                        
            
            PlayerUI.RemoveWidget(Canvas)

    # Constructs the loadout selection layout UI in a grid like fashion based on rows and cols
    ConstructMainUI(Buttons : []button_regular, TimerTextBlock : text_block) : stack_box =
        MainStackBox := stack_box:
            Orientation := orientation.Vertical
            Slots := array:
                stack_box_slot{Widget := TimerTextBlock, HorizontalAlignment := horizontal_alignment.Center}
        RowStackBoxes : []stack_box = for ( I := 0..Rows-1) {stack_box{Orientation := orientation.Horizontal}}
        var CurrentRowToUse : int = 0
        for ( Index->Button : Buttons, Loadout := Loadouts[Index], StackBox := RowStackBoxes[CurrentRowToUse]):
            StackBox.AddWidget(
                stack_box_slot:
                    Widget := ConstructLoadoutStackBox(Index, Button, Loadout.Name )
                    HorizontalAlignment := horizontal_alignment.Center
                    VerticalAlignment := vertical_alignment.Center
                    Padding := margin{ Left := ImageSize.X * 0.05 , Right := ImageSize.X * 0.05}
            )
            spawn { Button.AwaitSelection(Loadout, Index) }
            if ( Mod[Index, Columns] = Columns - 1):
                set CurrentRowToUse += 1
        for ( RowStackBox : RowStackBoxes):
            MainStackBox.AddWidget(
                stack_box_slot:
                    Widget := RowStackBox
                    HorizontalAlignment := horizontal_alignment.Center
                    VerticalAlignment := vertical_alignment.Center
                    Padding := margin{ Top := 30.0, Bottom := 30.0}
            )
        return MainStackBox

    # Constructs a single loadout UI slot containing name, image, and button
    ConstructLoadoutStackBox(Index : int, Button : button_regular, LoadoutName : string) : stack_box = 
        stack_box:
            Orientation := orientation.Vertical
            Slots := array:
                # Loadout Name / Text
                stack_box_slot:
                    Widget := text_block{ DefaultText := StringToText(LoadoutName) }
                    HorizontalAlignment := horizontal_alignment.Center
                # Image
                stack_box_slot:
                    Widget := overlay:
                        Slots := array:
                            overlay_slot:
                                Widget := color_block{ DefaultDesiredSize := ImageSize}
                            overlay_slot:
                                Widget := GetImageWidget(Index)
                    HorizontalAlignment := horizontal_alignment.Center
                # Selection Button
                stack_box_slot:
                    Widget := Button
                    HorizontalAlignment := horizontal_alignment.Center

    # Waits for a button to be clicked, signals player selection event
    (Button : button_regular).AwaitSelection(Loadout : loadout, ButtonIndex : int)<suspends> : void =
        race:
            block:
                WidgetMessage := Button.OnClick().Await()
                if ( set LoadoutToCurrentVotes[Loadout] += 1) {}
                PlayerSelectionEvent.Signal(button_selection_result{ Player := WidgetMessage.Player, Index := ButtonIndex})
                
            block:
                Time := 1.0 * int[VotingTime] or 10.0
                Sleep(Time)
        set CurrentVotes += 1
        if ( CurrentVotes >= MaxVotes ) then VoteEndedEvent.Signal()  

    # Calculates loadout to use
    CalculateMostVotedLoadout() : loadout =
        var GreatestVote : int = 0
        var WinningLoadout : loadout = loadout{}
        for ( Loadout->Vote : LoadoutToCurrentVotes):
            if ( Vote > GreatestVote) :
                set GreatestVote = Vote
                set WinningLoadout = Loadout
            if ( Vote = GreatestVote, GetRandomInt(1,2) = 1):
                set WinningLoadout = Loadout
        return WinningLoadout

    GetImageWidget(Index : int) : widget =
        if ( Texture := Textures[Index]):
            return texture_block:
                DefaultImage := Texture
                DefaultDesiredSize := 0.9 * ImageSize
        else:
            return color_block:
                DefaultColor := NamedColors.White
                DefaultDesiredSize := 0.9 * ImageSize

loadout := class<concrete><unique>:
    @editable       Name : string = "Loadout"
    @editable       ItemGranter : item_granter_device = item_granter_device{}

button_selection_result := struct:
    Player : player
    Index : int
