#Requires AutoHotkey v2.0
#SingleInstance Force
#Include <Class_ScrollableGui-ahk2>
ScrollableGui.init()
showGui()
F2::showGui()
F3::    {
    global myGui
    if (isSet(myGui) && myGui is gui)
        myGui.destroy(), myGui := ""
}
showGui()    {
    global myGui
    WS_HSCROLL := 0x00100000
    WS_VSCROLL := 0x00200000
    if (isSet(myGui) && myGui is gui)
        return
    prevIC := critical("On")
    myGui := gui()
    myGui.onEvent("Close", myGui_Close)
    myGui.setFont("Bold s16")
    myGui.add("Text",, " The scrollbar appears automatically.`nThis occurs when the window is resized.")
    myGui.setFont("Norm s10")
    myGui.add("Edit", "w480 r3 ReadOnly -Wrap", "
    (
    When the Edit control is focused, its scrollbar takes priority, functioning exclusively within the Edit area.
    This means that other scrollbars, like the one for the main window, will not respond while the Edit control is active.
    To scroll or manage the entire window, you first need to remove the focus from the Edit control.
    You can do this by clicking anywhere on the background of the window, outside the Edit control.
    Once the focus is removed, the main window's scrollbar will become active and available for use.
    This behavior has been carefully designed to include not only the Edit control but also ComboBox, DropDownList, and UpDown controls.
    )")
    myGui.add("ComboBox", "w480 Choose1", ["Red", "Green", "Blue"])
    myGui.add("DropDownList", "w480 Choose1", ["Black", "White", "Red"])
    myGui.add("Edit", "w480")
    myGui.add("UpDown", "Range1-10", 5)
    myGui.opt("+MaxSize +Resize")
    myGui.Title := "ScrollableGui Example 1"
    myGui.show("AutoSize")
    ScrollableGui.register(myGui)
    critical(prevIC)
}
myGui_Close(thisGui)    {
   global myGui
   myGui.destroy()
   myGui := ""
   return 0
}